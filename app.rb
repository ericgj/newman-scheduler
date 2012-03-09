require "bundler"
Bundler.require

require File.expand_path('app_libraries', File.dirname(__FILE__))
require File.expand_path('app_models', File.dirname(__FILE__))
require File.expand_path('app_presenters', File.dirname(__FILE__))

    
App = Newman::Application.new do

  helpers do

    # ----- Store helpers
    
    def store(key=:database)
      Newman::Store.new(settings.application.__send__(key))
    end
    
    # list keyed by list_id; elements keyed by insertion order
    def mailing_list(id)
      Newman::MailingList.new(id, store)
    end
    
    # elements keyed by autoincrementing ID
    def event_list
      Newman::Recorder.new('event', store(:events_db))
    end
    
    def subscribers
      mailing_list(params[:list_id]).subscribers
    end
    
    def subscriber?(addr)
      mailing_list(params[:list_id]).subscriber?(addr)
    end
    
    def create_event(e)
      event_list.create(params[:list_id]) { e }
    end
    
    
    # ----- Misc helpers
    
    # Note: default range of current date to 1 week from today
    def default_event_params
      { 
        :duration => 60,
        :range    => request.date...(request.date+7)
      }
    end
    
    def availability_address(list_id, event_id)
      "#{list_id}.event-avail-#{event_id}@#{domain}"
    end

    def schedule_address(list_id, event_id)
      "#{list_id}.event-sched-#{event_id}@#{domain}"
    end

    def usage_address(list_id)
      "#{list_id}.event-usage@#{domain}"
    end
    
    def add_response_footer(text, divider="-----")
      lines = response.text_part.to_s.split("\r\n")
      lines << "" << divider << text
      response.text_part = lines.join("\r\n")
    end
    
    def usage_response
      respond(
        :from    => "#{settings.service.default_sender}",
        :subject => "[#{params[:list_id]}] Scheduler usage",
        :body    => template('events/usage', :list_id => params[:list_id])
      )
    end
    
    # ----- accessors for use in views and to simplify controller code
    
    def new_event
      @new_event ||= Event.from_email(request, 
                                      default_event_params)
    end
    
  end


  match :list_id,      "[^\.]+"
  match :new,          "new"
  match :availability, "avail"
  match :schedule,     "sched"
  match :usage,        "usage"
  match :event_id,     "\d+"
  
  EVENT_NEW   = "{list_id}.event-{new}"
  EVENT_AVAIL = "{list_id}.event-{availability}-{event_id}"
  EVENT_SCHED = "{list_id}.event-{schedule}-{event_id}"
  EVENT_USAGE = "{list_id}.event-{usage}"
  
  
  to(:tag, EVENT_NEW) do
    
    unless subscriber?(sender)
      #TODO sender is not a subscriber
      next
    end
    
    rec = create_event(new_event)    
    event_id = rec.id
    
    forward_message(
        :from     => "On behalf of #{sender} <#{settings.service.default_sender}>",
        :bcc      => subscribers.join(', '),
        :reply_to => availability_address(params[:list_id], event_id)
    )
    
    add_response_footer template('event/footer', 
                                   :list_id  => params[:list_id],
                                   :event_id => event_id
                                )
    
  end
  
 
  to :tag, EVENT_USAGE, &method(:usage_response)
  
  default &method(:usage_response)
  
end
