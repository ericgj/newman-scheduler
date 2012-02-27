# Note: run from app root dir

require 'tempfile'
require File.expand_path('../../app', File.dirname(__FILE__))
require File.expand_path('../test_helper', File.dirname(__FILE__))

module IntegrationTests

  module Schedule
  
    module Helpers
      include IntegrationTests::Helpers
      
      def populate_mailing_list(list_id, *emails)
        emails.each do |email|
          mailing_list(list_id).subscribe email
        end
      end
      
      def fixture_message(fix)
        fixture = Schedule::Fixtures[fix]
        {
          :from => fixture[:from],
          :to   => fixture[:to],
          :subject => fixture[:subject],
          :body    => fixture[:body]
        }
      end
      
    end
    
    Fixtures = {
      
      :schedule_update => {
        :email   => 'snoopymcbeagle@example.com',
        :from    => 'Sal <snoopymcbeagle@example.com>',
        :to      => 'test+picnic.schedule-update@test.com',
        :subject => 'A picnic',
        :body    => ['week of Mar 12','90'].join("\r\n"),
        :list_id => 'picnic',
        :expected_name     => 'A picnic',
        :expected_duration => 90,
        :expected_range    => Date.civil(2012,3,12)...Date.civil(2012,3,19),
        :expected_response_from => "On behalf of snoopymcbeagle@example.com <test@test.com>",
        :expected_response_subject => "[A picnic] Requesting your availability",
        :expected_response_matchers => [/week of Mon 12 Mar/i, /1hr 30min/i]
      },

      :schedule_create => {
        :email   => 'snoopymcbeagle@example.com',
        :from    => 'Sal <snoopymcbeagle@example.com>',
        :to      => 'test+picnic.schedule-create@test.com',
        :subject => 'A picnic',
        :body    => ['week of Mar 12','90'].join("\r\n"),
        :list_id => 'picnic',
        :expected_name     => 'A picnic',
        :expected_duration => 90,
        :expected_range    => Date.civil(2012,3,12)...Date.civil(2012,3,19),
        :expected_response_from => "On behalf of snoopymcbeagle@example.com <test@test.com>",
        :expected_response_subject => "[A picnic] Requesting your availability",
        :expected_response_matchers => [/week of Mon 12 Mar/i, /1hr 30min/i]
      }
      
    }
    # -----
    
    describe 'event creation and update' do
      include Helpers    
    
      before do
        reset_storage
        @server = server([Newman::RequestLogger, App, Newman::ResponseLogger])
        @subscribers = ['dummy1@example.com', 
                        'dummy2@example.com', 
                        'dummy3@example.com']
      end
      
      [:schedule_update, :schedule_create].each do |fix|
      
        it 'should create or update event' do
          fixture = Fixtures[fix]
          populate_mailing_list fixture[:list_id], *@subscribers
          
          @server.mailer.deliver_message fixture_message(:schedule_update)
          @server.tick
          
          event = event_list.read(fixture[:list_id]).contents
          
          assert_equal 1, event_list.count
          refute_nil event
          assert_equal fixture[:expected_name], event.name
          assert_equal fixture[:expected_duration], event.duration
          assert_equal fixture[:expected_range], event.range
        end
        
        it 'if any subscribers, should forward "requesting availability" email' do
          fixture = Fixtures[fix]
          populate_mailing_list fixture[:list_id], *@subscribers
            

          @server.mailer.deliver_message fixture_message(:schedule_update)
          @server.tick
          
          msgs = @server.mailer.messages
          response = msgs.first
          
          assert_equal 1, msgs.count
          assert_equal fixture[:expected_response_subject],
                       response.subject,
                       response.to_s
                       
          fixture[:expected_response_matchers].each do |matcher|
            assert_match matcher, response.body.encoded
          end
          
          assert_equal @subscribers, response.bcc
          assert_equal fixture[:expected_response_from], response.from
          assert_equal [settings.application.availability_email], 
                       response.reply_to
        end
        
      end
      
    end
    
  end
  
  
end
