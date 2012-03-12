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
    def event_list(list_id)
      Newman::Recorder.new(list_id, store(:events_db))
    end
    
    def subscribers
      mailing_list(params[:list_id]).subscribers
    end
    
    # needed for gmail's stickler SMTP
    def subscriber_addresses
      subscribers.map {|sub| "#{sub} <#{sub}>"}
    end
    
    def subscriber?(addr)
      mailing_list(params[:list_id]).subscriber?(addr)
    end
    
    def create_event(e)
      event_list(params[:list_id]).create(e)
    end
    
    
    # ----- Misc helpers
    
    
    def default_sender_username
      settings.service.default_sender.split('@').first
    end
    
    def new_event_address(list_id)
      "Scheduler <#{default_sender_username}+#{list_id}.event-new@#{domain}>"
    end

    def availability_address(list_id, event_id)
      "Scheduler <#{default_sender_username}+#{list_id}.event-avail-#{event_id}@#{domain}>"
    end

    def schedule_address(list_id, event_id)
      "Scheduler <#{default_sender_username}+#{list_id}.event-sched-#{event_id}@#{domain}>"
    end

    def usage_address(list_id)
      "Scheduler usage <#{default_sender_username}+#{list_id}.event-usage@#{domain}>"
    end

    def response_body_lines
      if response.multipart?
        response.text_part.decoded.split("\r\n")
      else
        if response.body
          response.body.decoded.split("\r\n")
        else
          []
        end
      end   
    end
    
    # note this forces plain-text response currently
    def add_response_header(text, divider="-----")
      lines = response_body_lines
      lines = [text, "", divider] + lines 
      response.body = nil
      response.body = lines.join("\r\n")
    end
    
    # note this forces plain-text response currently
    def add_response_footer(text, divider="-----")
      lines = response_body_lines
      lines << "" << divider << text
      response.body = nil
      response.body = lines.join("\r\n")
    end
    
    def sender_name
      request[:from].display_names.first
    end
    
    def reply_subject
      orig = request.subject || ''
      [ "RE:",
         orig.gsub(/^RE:/i,"")
      ].join(" ")
    end
    
    def usage_response
      respond(
        :from    => "Scheduler usage <#{settings.service.default_sender}>",
        :subject => "#{params[:list_id]} -- scheduler instructions",
        :body    => template('shared/usage', :list_id => params[:list_id])
      )
    end

    
    # ----- accessors for use in views and to simplify controller code
    
    def new_event
      @new_event ||= Event.from_email(request)
    end
    
    def existing_event
      @existing_event ||= event_list(params[:list_id]).
                            read(params[:event_id].to_i).contents
    end
    
    def update_existing_event(&upd)
      event_list(params[:list_id]).update(params[:event_id].to_i, &upd)
    end

    def destroy_existing_event
      event_list(params[:list_id]).destroy(params[:event_id].to_i)
    end
    
    # note this only is reliable if we store canonical email addresses
    def missing_subscribers
      @missing_subscribers ||= subscribers - 
                               existing_event.participants.map(&:email)
    end
    
  end


  match :list_id,      "[^\.]+"
  match :new,          "new"
  match :availability, "avail"
  match :schedule,     "sched"
  match :cancel,       "cancel"
  match :usage,        "usage"
  match :event_id,     "[^\.]+"
  
  EVENT_NEW    = "{list_id}.event-{new}"
  EVENT_AVAIL  = "{list_id}.event-{availability}-{event_id}"
  EVENT_SCHED  = "{list_id}.event-{schedule}-{event_id}"
  EVENT_CANCEL = "{list_id}.event-{cancel}-{event_id}"
  EVENT_USAGE  = "{list_id}.event-{usage}"
    
  
  to(:tag, EVENT_NEW) do
    
    logger.debug("NEWMAN-SCHEDULER: EVENT-NEW") { params.inspect }
    
    unless subscriber?(sender)
      #TODO sender is not a subscriber -- or handle downstream?
      next
    end
    
    unless new_event.valid?
      respond(
        :from    => "Scheduler usage <#{settings.service.default_sender}>",
        :subject => reply_subject + " -- invalid syntax",
        :body    => template('event/invalid',
                               :event => new_event,
                               :list_id  => params[:list_id]
                            )
      )
      next
    end
    
    rec = create_event(new_event)
    event_id = rec.id
    
    forward_message(
        :from     => "On behalf of #{sender_name} <#{settings.service.default_sender}>",
        :to       => '',
        :bcc      => subscribers.join(', '),
        :reply_to => availability_address(params[:list_id], event_id)
    )
    
    add_response_footer template('event/_footer', 
                                   :list_id  => params[:list_id],
                                   :event_id => event_id
                                )
    
  end
 

  to(:tag, EVENT_AVAIL) do
    
    logger.debug("NEWMAN-SCHEDULER: EVENT-AVAIL") { params.inspect }
    
    unless subscriber?(sender)
      #TODO sender is not a subscriber -- or handle downstream?
      next
    end
    
    unless existing_event
      respond(
        :from    => "Scheduler <#{settings.service.default_sender}>",
        :subject => reply_subject + " -- no event found",
        :body    => template('shared/no_event',
                               :list_id  => params[:list_id],
                               :event_id => params[:event_id]
                            )
      )
      next
    end
    
    partic = Participant.from_email(request)
    
    unless partic.valid?
      respond(
        :from    => "Scheduler usage <#{settings.service.default_sender}>",
        :subject => reply_subject + " -- invalid syntax",
        :body    => template('availability/invalid',
                               :event       => existing_event,
                               :participant => partic,
                               :list_id     => params[:list_id],
                               :event_id    => params[:event_id]
                            )
      )
      next
    end
    
    update_existing_event do |event|
      event.participants.delete_if {|p| p.email == partic.email}
      event.participants << partic
      event
    end
   
    respond(
      :from    => "Scheduler <#{settings.service.default_sender}>",
      :subject => reply_subject,
      :body    => template('availability/confirmation',
                             :event    => existing_event,
                             :list_id  => params[:list_id],
                             :event_id => params[:event_id]
                          )
    )
    
  end
  
  to(:tag, EVENT_SCHED) do
   
    logger.debug("NEWMAN-SCHEDULER: EVENT-SCHED") { params.inspect }

    unless subscriber?(sender)
      #TODO sender is not a subscriber -- or handle downstream?
      next
    end
            
    unless existing_event
      respond(
        :from    => "Scheduler <#{settings.service.default_sender}>",
        :subject => reply_subject + " -- no event found",
        :body    => template('shared/no_event',
                               :list_id  => params[:list_id],
                               :event_id => params[:event_id]
                            )
      )
      next
    end
    
    event = Presenters::SimpleEvent.new(existing_event)
    
    if event.participants.count < 2
      respond(
        :from    => "Scheduler <#{settings.service.default_sender}>",
        :subject => reply_subject + " -- unable to select best times to meet",
        :body    => template('schedule/no_participants', 
                               :event => event,
                               :list_id  => params[:list_id],
                               :event_id => params[:event_id]
                            )
      )
      next
    end
    
    respond(
      :from    => "Scheduler <#{settings.service.default_sender}>",
      :subject => reply_subject,
      :body    => template('schedule/best', :event => event)
    )

  end
  
  to(:tag, EVENT_CANCEL) do
   
    logger.debug("NEWMAN-SCHEDULER: EVENT-SCHED") { params.inspect }

    unless subscriber?(sender)
      #TODO sender is not a subscriber -- or handle downstream?
      next
    end
    
    #TODO possibly should also check if sender == event proposer ?
    
    unless existing_event
      respond(
        :from    => "Scheduler <#{settings.service.default_sender}>",
        :subject => reply_subject + " -- no event found",
        :body    => template('shared/no_event',
                               :list_id  => params[:list_id],
                               :event_id => params[:event_id]
                            )
      )
      next
    end
    
    destroy_existing_event
    
    forward_message(
      :from    => "On behalf of #{sender_name} <#{settings.service.default_sender}>",
      :to      => '',
      :bcc     => subscribers.join(', ')
    )
    
    add_response_header template('event/_cancel', 
                                 :event    => existing_event,
                                 :list_id  => params[:list_id],
                                 :event_id => params[:event_id]
                        )
  end
  
  to(:tag, EVENT_USAGE) do
        
    logger.debug("NEWMAN-SCHEDULER: EVENT-USAGE") { params.inspect }
    
    unless subscriber?(sender)
      #TODO sender is not a subscriber -- or handle downstream?
      next
    end
  
    usage_response  
  end
  
  default do
  end
  
end



SimpleMailingList = Newman::Application.new do

  helpers do

    # ----- Store helpers
    
    def store(key=:database)
      Newman::Store.new(settings.application.__send__(key))
    end
    
    # list keyed by list_id; elements keyed by insertion order
    def mailing_list(id)
      Newman::MailingList.new(id, store)
    end

    def subscribers
      mailing_list(params[:list_id]).subscribers
    end
    
    def subscriber?(addr)
      mailing_list(params[:list_id]).subscriber?(addr)
    end
        
    def reply_subject
      orig = request.subject || ''
      [ "RE:",
         orig.gsub(/^RE:/i,"")
      ].join(" ")
    end
    
  end
  
  match :list_id,      "[^\.]+"

  to(:tag, "{list_id}.subscribe") do
    
    unless subscriber?(sender)
      
      mailing_list(params[:list_id]).subscribe(sender)
    
      respond(
        :from => "Scheduler <#{settings.service.default_sender}>",
        :subject => reply_subject + " -- you are subscribed"
      )
    end
  
  end

  to(:tag, "{list_id}.unsubscribe") do
    
    if subscriber?(sender)
      
      mailing_list(params[:list_id]).unsubscribe(sender)
    
      respond(
        :from => "Scheduler <#{settings.service.default_sender}>",
        :subject => reply_subject + " -- you are unsubscribed"
      )
    end
  
  end
  
  default do
  end
  
end
