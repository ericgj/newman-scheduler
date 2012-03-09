require File.expand_path('../app', File.dirname(__FILE__))

gem "minitest"
require 'minitest/autorun'
require "purdytest"

module IntegrationTests

  module Helpers

    TEST_DIR = File.dirname(__FILE__)
    
    def new_test_server(apps)
      apps = Array(apps)  
      server = Newman::Server.test_mode(environment_file)
      apps.each {|app| server.apps << app }    
      server.logger = logger
      server
    end
    
    def environment_file
      File.expand_path('config/settings.rb', TEST_DIR)
    end
    
    def logger
      log = ::Logger.new( File.expand_path("log/integration.log",
                                           TEST_DIR)
                        )
      log.level = ::Logger::DEBUG
      log
    end
    
    def reset_storage(*keys)
      keys = [:database, :events_db] if keys.empty?
      keys.each do |key|
        file = settings.application.__send__(key)
        File.delete(file) if File.exist?(file)
      end
    end

    def mailing_list(id)
      Newman::MailingList.new(id, store)
    end
    
    def event_list(list_id)
      Newman::Recorder.new(list_id, store(:events_db))
    end
    
    def settings
      settings = Newman::Settings.from_file(environment_file)  
    end
    
    def store(key=:database)
       Newman::Store.new(settings.application.__send__(key))
    end
    
  end  
  
end