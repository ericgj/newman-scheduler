require 'tempfile'
require File.expand_path('../app', File.dirname(__FILE__))

require 'minitest/spec'
MiniTest::Unit.autorun

module IntegrationTests

  #TODO most of these should be moved to a test helper file
  
  module Helpers
    def environment_file
      return @environment_file if @environment_file
      f = Tempfile.new("test_environment")
      f.write <<-_____
service.domain           = "test.com"
service.templates_dir    = "app/views"
service.default_sender   = "test@test.com"
service.debug_mode       = true      
application.database           = "test/temp/mailing_list.store"
application.availability_db    = "test/temp/availability.store"
application.events_db          = "test/temp/events.store"
      _____
      f.close
      @environment_file = f.path
    end
    
    def settings
      settings = Newman::Settings.from_file(environment_file)  
    end
    
    def store(key)
       Newman::Store.new(settings.application.__send__(key))
    end
    
    def logger
      return @logger if @logger
      log = ::Logger.new( File.expand_path("log/integration.log",
                              File.dirname(__FILE__))
                        )
      log.level == ::Logger::DEBUG
      @logger = log
    end
    
    def server
      server = Newman::Server.test_mode(environment_file)
      server.apps << Newman::RequestLogger << App << Newman::ResponseLogger
      server.logger = logger
      server
    end

      
    def reset_storage
      [settings.application.database,
       settings.application.events_db,
       settings.application.availability_db].each do |file|
         File.delete(file) if File.exist?(file)
       end
    end
    
    def availability_list(id)
      Newman::KeyRecorder.new(id, store(:availability_db))
    end
  end
  
  describe 'availability' do
    include Helpers
    
    before do
      reset_storage
      @server = server
    end
    
    it 'should store participant keyed by sender email' do
      @server.mailer.deliver_message(
        :to => "test+availability@test.com",
        :from => "Flynn <flynnflys@example.com>",
        :subject => "2012-03-05 -04:00",
        :body  => ["Mon Tue Wed", "1pm - 3pm"].join("\r\n")
      )
      @server.tick
      
      list = availability_list( Date.civil(2012,3,5)...Date.civil(2012,3,12) )
      partic = list.read("flynnflys@example.com").contents

      assert_equal 1, list.count
      refute_nil partic
      assert_equal "Flynn", partic.name
      
    end
    
  end
  
end

