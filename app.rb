require "bundler"
Bundler.require

require File.expand_path('app/models/event', File.dirname(__FILE__))
require File.expand_path('app/models/availability', File.dirname(__FILE__))

scheduler = Newman::Application.new do

  helpers do
    attr_accessor :list, :event
    
    def subscribers
      self.list.subscribers    
    end

    def subscribers_list
      subscribers.join(', ')
    end
    
    def find_or_create_event_participant
      unless p = self.event.participants.find(:email => sender)
        p = Participant.new(:email => sender)
        self.event.participants << p
      end
      p
    end
    
    def respond_request_availability(overrides={})
      respond(
        { :subject => "Requesting your availability for: #{self.event.name}",
          :body    => template('event-created-with-instructions'),
          :from    => sender
        }.merge(overrides)
      )
    end

    def respond_best_availability(overrides={})
      respond(
        { :subject => "Best times for: #{self.event.name}",
          :body    => template('best'),
          :from    => sender
        }.merge(overrides)
      )
    end
    
  end
  
  match :list_id,  ".+"
  match :update,   "^\+\s*"
  match :delete,   "^\-\s*"
  match :index,    "^\?\s*"
  match :command,  "(best|all)"
  
  to(:tag, "{list_id}.schedule") do
    self.list  = MailingList.find(:id => params[:list_id])
    self.event = Event.find(:id => params[:list_id])
    unless self.event
      self.event = Event.from_email(request)
      self.event.save
    end
    respond_request_availability :bcc => subscribers_list
  end
  
  subject(:match, "{update}available") do
    person = find_or_create_event_participant
    person.add_availability_from_email(request)
    person.save
    respond_best_availability :bcc => subscribers_list
  end

  subject(:match, "{delete}available") do
    person = find_or_create_event_participant
    person.reset_availability
    person.save
    respond_best_availability :bcc => subscribers_list
  end
  
  subject(:match, "{index}{command}") do  
  
  end
  
end