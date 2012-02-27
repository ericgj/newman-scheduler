# Note: run from app root dir

require 'tempfile'
require File.expand_path('../../app', File.dirname(__FILE__))
require File.expand_path('../test_helper', File.dirname(__FILE__))

module IntegrationTests

  module Availability
  
    # -----
    
    describe 'availability' do
      include IntegrationTests::Helpers
      
      before do
        reset_storage
        @server = server([Newman::RequestLogger, App, Newman::ResponseLogger])
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
  
end
