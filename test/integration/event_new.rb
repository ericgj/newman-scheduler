# Note: run from app root dir

require File.expand_path('../test_helper', File.dirname(__FILE__))

module IntegrationTests
  module EventNew
  
    module Helpers
      include IntegrationTests::Helpers
      
      def server
        @server ||= new_test_server(
                      [Newman::RequestLogger, App, Newman::ResponseLogger]
                    )
      end
      
      def reset_inbox
        server.mailer.messages; nil
      end
      
      def process_fixture_messages(*fixs)
        fixs.each do |fix|
          server.mailer.deliver_message fixture_message(fix)
        end
        server.tick
        server.mailer.messages
      end
      
      def populate_mailing_list(list_id, *emails)
        emails.each do |email|
          mailing_list(list_id).subscribe email
        end
      end
      
      def populate_mailing_list_from_fixtures(list_fix, *fixs)
        populate_mailing_list Fixtures[list_fix][:list_id],
                              *fixs.map {|f| Fixtures[f][:email] }
      end
      
      def fixture_message(fix)
        fixture = EventNew::Fixtures[fix]
        {
          :from => fixture[:from],
          :to   => fixture[:to],
          :subject => fixture[:subject],
          :body    => fixture[:body]
        }
      end
      
    end
    
    Fixtures = {
      
      :basic => {
        :email   => 'snoopymcbeagle@example.com',
        :from    => 'Sal <snoopymcbeagle@example.com>',
        :to      => 'test+list.event-new@test.com',
        :subject => 'Availability for a picnic | week of Mar 12 | 90',
        :body    => ['Can we have a picnic this week?',''].join("\r\n"),
        :list_id => 'list',
        :expected_name     => 'a picnic',
        :expected_duration => 90,
        :expected_range    => Date.civil(2012,3,12)...Date.civil(2012,3,19),
        :expected_response_from     => "On behalf of snoopymcbeagle@example.com <test@test.com>",
        :expected_reply_to          => "test+list.event-avail-1@test.com",
        :expected_response_subject  => "Availability for a picnic | week of Mar 12 | 90",
        :expected_response_matchers => []
      },
      :simple_subject => {
        :email   => 'snoopymcbeagle@example.com',
        :from    => 'Sal <snoopymcbeagle@example.com>',
        :to      => 'test+list.event-new@test.com',
        :subject => 'A picnic | week of Mar 12 | 90',
        :body    => ['Can we have a picnic this week?',''].join("\r\n"),
        :list_id => 'list',
        :expected_name     => 'A picnic',
        :expected_duration => 90,
        :expected_range    => Date.civil(2012,3,12)...Date.civil(2012,3,19),
        :expected_response_from     => "On behalf of snoopymcbeagle@example.com <test@test.com>",
        :expected_reply_to          => "test+list.event-avail-1@test.com",
        :expected_response_subject  => "A picnic | week of Mar 12 | 90",
        :expected_response_matchers => []
      },
      :no_range_or_duration => {
        :email   => 'snoopymcbeagle@example.com',
        :from    => 'Sal <snoopymcbeagle@example.com>',
        :to      => 'test+list.event-new@test.com',
        :subject => 'A picnic',
        :body    => ['Can we have a picnic this week?',''].join("\r\n"),
        :list_id => 'list',
        :expected_name     => 'A picnic',
        :expected_duration => nil,
        :expected_range    => nil,
        :expected_response_from     => "Scheduler usage <test@test.com>",
        :expected_reply_to          => [],
        :expected_response_subject  => "RE: A picnic -- invalid syntax",
        :expected_response_matchers => [%r{Sorry, your message "A picnic"},
                                        %r{## HOW TO PROPOSE AN EVENT TO THE LIST list}
                                       ]
      },
      :no_duration => {
        :email   => 'snoopymcbeagle@example.com',
        :from    => 'Sal <snoopymcbeagle@example.com>',
        :to      => 'test+list.event-new@test.com',
        :subject => 'A picnic | week of Mar 12',
        :body    => ['Can we have a picnic this week?',''].join("\r\n"),
        :list_id => 'list',
        :expected_name     => 'A picnic',
        :expected_duration => nil,
        :expected_range    => Date.civil(2012,3,12)...Date.civil(2012,3,19),
        :expected_response_from     => "Scheduler usage <test@test.com>",
        :expected_reply_to          => [],
        :expected_response_subject  => "RE: A picnic | week of Mar 12 -- invalid syntax",
        :expected_response_matchers => [%r{Sorry, your message "A picnic | week of Mar 12"},
                                        %r{## HOW TO PROPOSE AN EVENT TO THE LIST list}
                                       ]
      }

    }
    
    # -----
    
    describe 'event creation' do
      include Helpers    
    
      before do
        reset_storage
        reset_inbox
      end
      
      [:basic, :simple_subject].each do |fix|
      
        it 'should create event' do
          fixture = Fixtures[fix]
          subscribers = [fixture[:email],
                         'dummy1@example.com',
                         'dummy2@example.com',
                         'dummy3@example.com']
          populate_mailing_list fixture[:list_id], *subscribers
          
          process_fixture_messages fix
          
          assert_equal 1, event_list(fixture[:list_id]).count
          
          rec      = event_list(fixture[:list_id]).first
          event_id = rec.id
          event    = rec.contents
          
          assert_equal 1, event_id
          refute_nil event
          assert_equal fixture[:expected_name], event.name
          assert_equal fixture[:expected_duration], event.duration
          assert_equal fixture[:expected_range], event.range
        end
        
        it 'should forward "requesting availability" email' do
          fixture = Fixtures[fix]
          subscribers = [fixture[:email],
                         'dummy1@example.com',
                         'dummy2@example.com',
                         'dummy3@example.com']
          populate_mailing_list fixture[:list_id], *subscribers
            
          msgs = process_fixture_messages fix

          response = msgs.first
          body     = response.decoded
          
          assert_equal 1, msgs.count
          assert_equal fixture[:expected_response_subject],
                       response.subject,
                       response
                       
          assert_equal subscribers, 
                       response.bcc
          assert_equal fixture[:expected_response_from], 
                       response[:from].decoded
          assert_equal [fixture[:expected_reply_to]], 
                       response.reply_to
                       
          fixture[:expected_response_matchers].each do |matcher|
            assert_match matcher, body
          end
          
        end
        
      end
      
    end
    
    describe "event creation, bad syntax" do
      include Helpers    
    
      before do
        reset_storage
        reset_inbox
      end
      
      [:no_range_or_duration, :no_duration].each do |fix|
          
        it 'should not create event' do
          fixture = Fixtures[fix]
          subscribers = [fixture[:email],
                         'dummy1@example.com',
                         'dummy2@example.com',
                         'dummy3@example.com']
          populate_mailing_list fixture[:list_id], *subscribers
          
          process_fixture_messages fix
          
          assert_equal 0, event_list(fixture[:list_id]).count

        end
        
        it 'should reply "invalid syntax" email' do
          fixture = Fixtures[fix]
          subscribers = [fixture[:email],
                         'dummy1@example.com',
                         'dummy2@example.com',
                         'dummy3@example.com']
          populate_mailing_list fixture[:list_id], *subscribers
            
          msgs = process_fixture_messages fix

          response = msgs.first
          body     = response.decoded
          
          assert_equal 1, msgs.count
          assert_equal fixture[:expected_response_subject],
                       response.subject,
                       response
                       
          assert_equal fixture[:expected_response_from], 
                       response[:from].decoded
          assert_equal [fixture[:email]], 
                       response.to
                       
          fixture[:expected_response_matchers].each do |matcher|
            assert_match matcher, body
          end
          
        end
        
      end
      
    end
  
  end
end  