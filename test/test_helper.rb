require "bundler"
Bundler.require

require File.expand_path('../app_libraries', File.dirname(__FILE__))
require File.expand_path('../app_models', File.dirname(__FILE__))
require File.expand_path('../app_presenters', File.dirname(__FILE__))

require 'minitest/spec'
MiniTest::Unit.autorun

module IntegrationTests

  module Helpers

    TEST_DIR = File.dirname(__FILE__)
    
    def environment_file
      File.expand_path('config/settings.rb', TEST_DIR)
    end
    
    def settings
      settings = Newman::Settings.from_file(environment_file)  
    end
    
    def store(key=:database)
       Newman::Store.new(settings.application.__send__(key))
    end
    
    def logger
      log = ::Logger.new( File.expand_path("log/integration.log",
                                           TEST_DIR)
                        )
      log.level = ::Logger::DEBUG
      log
    end
    
    def server(apps)
      apps = Array(apps)
      server = Newman::Server.test_mode(environment_file)
      apps.each {|app| server.apps << app}
      server.logger = logger
      server
    end
      
    def reset_storage(*keys)
      keys = [:database, :events_db, :availability_db] if keys.empty?
      keys.each do |key|
        file = settings.application.__send__(key)
        File.delete(file) if File.exist?(file)
      end
    end

    def mailing_list(id)
      Newman::MailingList.new(id, store)
    end
    
    def availability_list(id)
      Newman::KeyRecorder.new(id, store(:availability_db))
    end

    def event_list
      Newman::KeyRecorder.new('event', store(:events_db))
    end
    
  end  
  
end