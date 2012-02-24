require "bundler"
Bundler.require

require File.expand_path('app_libraries', File.dirname(__FILE__))
require File.expand_path('app_models', File.dirname(__FILE__))

scheduler = Newman::Application.new do

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
      Newman::KeyRecorder.new(id, store(:availability))
    end
    
    # elements keyed by list_id
    def event_list
      Newman::KeyRecorder.new('event', store(:events))
    end
    
  end
  
  match :list_id,  "[^\.]+"
  match :update,   "$"
  match :show,     "\-show$"
  match :index,    "\-list$"
  match :delete,   "\-delete$"
  
  # Send in my availability for the specified week and timezone
  # Note: no response; assumes mailing-list app will do that
  to(:tag, "availability") do
    avail = Participant.from_email(request)
    availability_list(avail.range).update(avail.email) { avail }
  end
  
  # Specify the date or date-range of an event and its duration
  # Responds to entire list with email requesting availability
  #
  # Note that if duration and range and name not specified in request email,
  # defaults to hour-long event happening on date the email was sent,
  # named the same as the list_id
  #
  to(:tag, "{list_id}.schedule{update}") do
    list_id = params[:list_id]
    
    event = Event.from_email(request, 
                             :name     => list_id, 
                             :duration => 60,
                             :range    => request.date...(request.date+1)
                            )
    event_list.update(list_id) { event }
    
    subscribers = mailing_list(list_id).subscribers
    
    if !subscribers.empty?
      forward_message(
          :subject  => "[#{event.name}] Requesting your availability",
          :body     => template('event/show'),
          :bcc => subscribers.join(', ')
      )
    end
  end
  
  # What are the current best times to meet for all subscribers to the given 
  # list/event?
  # Responds to entire list with the best timeslots
  to(:tag, "{list_id}.schedule{index}") do
    list_id = params[:list_id]
    
    event = event_list.read(list_id)
    subscribers = mailing_list(list_id).subscribers
    if event && !subscribers.empty?
     
      avails = availability_list(event.week)
      subscriber_avails = avails.select {|person| 
        subscribers.include?(person.email)
      }
      
      subscriber_avails.each do |person|
        event.participants << person
      end
      
      if event.participants > 1
        respond(
          :subject => "[#{event.name}] Best times to meet",
          :body    => template('schedule/best'),
          :bcc => subscribers.join(', ')
        )
      else
        respond(
          :subject => "[#{event.name}] Unable to select best times to meet",
          :body    => template('schedule/error-no-participants'),
          :to      => sender
        )        
      end
    end
  end
  
  # What are the current available timeslots for specified email address 
  # (or myself if no email address specified) for given list/event?
  # Responds to sender with all available timeslots for specified email address.
  to(:tag, "{list_id}.schedule{show}") do
    list_id = params[:list_id]
    
    email = request.subject.strip
    email = sender if email.empty?    # default to sender if no subject
    
    event = event_list.read(list_id)
    if event
    
      avail = availability_list(event.week).read(email)
      
      if avail
        event.participants << avail
            
        respond(
          :subject => "[#{event.name}] available times for: #{email}",
          :body    => template('schedule/show'),
          :to      => sender
        )
      else
        respond(
          :subject => "[#{event.name}] available times unknown for: #{email}",
          :body    => template('schedule/error-no-availability'),
          :to      => sender
        )      
      end
    end
  end
  
end