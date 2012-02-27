require "bundler"
Bundler.require

require File.expand_path('app_libraries', File.dirname(__FILE__))
require File.expand_path('app_models', File.dirname(__FILE__))
require File.expand_path('app_presenters', File.dirname(__FILE__))

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
                  "#{avail.range.begin}...#{avail.range.end}"
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
    
    event = Event.from_email(request, default_event_params(list_id))
    event_list.update(list_id) { event }
    
    subscribers = mailing_list(list_id).subscribers
    
    if subscribers.empty?
      #TODO no subscribers or no such mailing list
      next
    end
    
    event = Presenters::SimpleEvent.new(event)
    
    forward_message(
        :subject  => "[#{event.name}] Requesting your availability",
        #:body     => template('event/show'),
        :bcc => subscribers.join(', ')#,
        #:reply_to => settings.application.availability_email
    )
  end
  
  # What are the current best times to meet for all subscribers to the given 
  # list/event?
  # Responds to entire list with the best timeslots
  to(:tag, "{list_id}.schedule{index}") do
    list_id = params[:list_id]
    
    event_rec = event_list.read(list_id)
    subscribers = mailing_list(list_id).subscribers
    unless event_rec
      # TODO unknown event
      next
    end
    
    if subscribers.empty?
      # TODO no subscribers
      next
    end
    
    event = event_rec.contents
    avails = availability_list(event.week).map(&:contents)
    subscriber_avails = avails.select {|person| 
      subscribers.include?(person.email)
    }
    
    subscriber_avails.each do |person|
      event.participants << person
    end
    
    if event.participants <= 1
      respond(
        :subject => "[#{event.name}] Unable to select best times to meet",
        :body    => template('schedule/error-no-participants'),
        :to      => sender
      )
      next
    end
    
    respond(
      :subject => "[#{event.name}] Best times to meet",
      :body    => template('schedule/best'),
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
    
    event_rec = event_list.read(list_id)
    unless event_rec
      # TODO unknown event
      next
    end
    
    event = event_rec.contents
    avail_rec = availability_list(event.week).read(email)
    
    unless avail_rec
      respond(
        :subject => "[#{event.name}] available times unknown for: #{email}",
        :body    => template('schedule/error-no-availability'),
        :to      => sender
      )      
      next
    end    
    
    avail = avail_rec.contents
    event.participants << avail
        
    respond(
      :subject => "[#{event.name}] available times for: #{email}",
      :body    => template('schedule/show'),
      :to      => sender
    )

  end
  
end