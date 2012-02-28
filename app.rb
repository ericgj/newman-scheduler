require "bundler"
Bundler.require

require File.expand_path('app_libraries', File.dirname(__FILE__))
require File.expand_path('app_models', File.dirname(__FILE__))
require File.expand_path('app_presenters', File.dirname(__FILE__))

#=================== patch
module Newman
  class Controller
  
    def template(name,locals={})
      Tilt.new(Dir.glob("#{settings.service.templates_dir}/#{name}.*").first)
          .render(self,locals)
    end
    
  end
end
#==================
    
App = Newman::Application.new do

  helpers do
    
    def store(key=:database)
      Newman::Store.new(settings.application.__send__(key))
    end
    
    # list keyed by list_id; elements keyed by insertion order
    def mailing_list(id)
      Newman::MailingList.new(id, store)
    end
    
    # list keyed by date-range; elements keyed by email
    def availability_list(id)
      Newman::KeyRecorder.new(id, store(:availability_db))
    end
    
    # elements keyed by list_id
    def event_list
      Newman::KeyRecorder.new('event', store(:events_db))
    end
    
    def default_event_params(list_id)
      { 
        :name     => list_id, 
        :duration => 60,
        :range    => request.date...(request.date+1)
      }
    end
    
    def subscriber_availability_for_week(range)
      avails = availability_list(range).map(&:contents)
      avails.select {|person| 
        subscribers.include?(person.email)
      }
    end
    
    def availability_for_week(range, email)
      rec = availability_list(range).read(email)
      rec.contents if rec
    end
    
    # ----- accessors for use in views and to simplify controller code
    
    def subscribers
      @subscribers ||= mailing_list(params[:list_id]).subscribers
    end
    
    def new_event
      @new_event ||= Event.from_email(
                        request, default_event_params(params[:list_id]))
    end
    
    def existing_event
      return @existing_event if @existing_event
      event_rec = event_list.read(params[:list_id])
      @existing_event = event_rec.contents if event_rec
    end
    
  end
  
  match :list_id,  "[^\.]+"
  match :update,   "\-(update|create)"
  match :show,     "\-show"
  match :index,    "\-list"
  match :delete,   "\-delete"
  
  # Send in my availability for the specified week and timezone
  # Responds with a confirmation email; note if you have a mailing list app
  # downstream of this, instead the request will be forwarded to the list.
  to(:tag, "availability") do
    avail = Participant.from_email(request)
    availability_list(avail.range).update(avail.email) { avail }
    respond(
      :subject => "[availability] #{avail.name} " + 
                  "#{avail.range.begin}...#{avail.range.end} #{avail.availables.first.utc_offset}"
    )
  end

  
  # Specify the date or date-range of an event and its duration
  # Responds to entire list with email requesting availability
  # With the availability email as the reply-to address
  #
  # Note that if duration and range and name not specified in request email,
  # defaults to hour-long event happening on date the email was sent,
  # named the same as the list_id
  #
  to(:tag, "{list_id}.schedule{update}") do
    list_id = params[:list_id]
    
    event_list.update(list_id) { new_event }
    
    if subscribers.empty?
      #TODO no subscribers or no such mailing list
      next
    end
    
    event = Presenters::SimpleEvent.new(new_event)
    
    respond(
        :from     => "On behalf of #{sender} <#{settings.service.default_sender}>",
        :bcc      => subscribers.join(', '),
        :reply_to => settings.application.availability_email,
        :subject  => "[#{event.name}] Requesting your availability",
        :body     => template('event/proposal', :event => event)
    )
  end
  
  # What are the current best times to meet for all subscribers to the given 
  # list/event?
  # Responds to entire list with the best timeslots
  to(:tag, "{list_id}.schedule{index}") do
    
    unless existing_event
      # TODO unknown event
      next
    end
    
    if subscribers.empty?
      # TODO no subscribers
      next
    end
        
    subscriber_availability_for_week(existing_event.week).each do |partic|
      existing_event.participants << partic
    end
    
    event = Presenters::SimpleEvent.new(existing_event)
    
    if event.participants.count <= 1
      respond(
        :subject => "[#{event.name}] Unable to select best times to meet",
        :body    => template('event/error_no_participants', :event => event),
        :to      => sender
      )
      next
    end
    
    respond(
      :subject => "[#{event.name}] Best times to meet",
      :body    => template('event/best', :event => event),
      :bcc => subscribers.join(', ')
    )
    
  end
  
  # What are the current available timeslots for specified email address 
  # (or myself if no email address specified) for given list/event?
  # Responds to sender with all available timeslots for specified email address.
  to(:tag, "{list_id}.schedule{show}") do
    list_id = params[:list_id]
    
    email = request.subject.strip
    email = sender if email.empty?    # default to sender if no subject
    
    unless existing_event
      # TODO unknown event
      next
    end
    
    partic = availability_for_week(existing_event.week, email) 
    
    unless partic
      respond(
        :subject => "[#{event.name}] availability unknown for: #{email}",
        :body    => template('event/error_no_availability'),
        :to      => sender
      )      
      next
    end    
    
    existing_event.participants << partic
    
    event = Presenters::SimpleEvent.new(existing_event)
    
    logger.debug "******* #{partic.email} *******\n" + 
                 existing_event.participants.first.availables.inspect + "\n" +
                 existing_event.coalesced.inspect
                 
    respond(
      :subject => "[#{event.name}] Available times for: #{email}",
      :body    => template('event/show', :event => event),
      :to      => sender
    )

  end
  
end