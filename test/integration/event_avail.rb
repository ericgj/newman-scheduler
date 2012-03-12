# Note: run from app root dir

require File.expand_path('../test_helper', File.dirname(__FILE__))

module IntegrationTests
  module EventAvail
  
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
      
      def create_event_from_fixture(fix)
        fixture = EventAvail::Fixtures[fix]
        list_id = fixture[:list_id]
        event_list(list_id).create(fixture_event(fix))
      end
      
      def fixture_message(fix)
        fixture = EventAvail::Fixtures[fix]
        {
          :from => fixture[:from],
          :to   => fixture[:to],
          :subject => fixture[:subject],
          :body    => fixture[:body]
        }
      end
      
      def fixture_event(fix)
        fixture = EventAvail::Fixtures[fix]
        Event.new(fixture[:name]) do
          duration fixture[:duration]
          range    fixture[:range]
        end
      end
      
    end
    
    Fixtures = {
    
      :dummy_event => {
        :list_id => 'list',
        :name => 'birthday party',
        :duration => 120,
        :range => Date.civil(2012,3,14)...Date.civil(2012,3,15)
      },
      
      :basic => {
        :email   => 'snoopymcbeagle@example.com',
        :from    => 'Sal <snoopymcbeagle@example.com>',
        :to      => 'test+list.event-avail-1@test.com',
        :subject => 'my availability',
        :body    => ['   +09:00',
                   'Mon Wed Fri', 
                   '12:30pm - 20:00'].join("\r\n"),
        :list_id => 'list',
        :expected_availables => [
          {:days => [1,3,5], :from => '12:30pm', :to => '20:00', :utc_offset => '+09:00'}
        ],
        :expected_response_from     => "Scheduler <test@test.com>",
        :expected_response_subject  => "RE: my availability",
        :expected_response_matchers => []      
      },
      
      :empty_body => {
        :email   => 'snoopymcbeagle@example.com',
        :from    => 'Sal <snoopymcbeagle@example.com>',
        :to      => 'test+list.event-avail-1@test.com',
        :subject => 'my availability',
        :body    => [''].join("\r\n"),
        :list_id => 'list',
        :expected_availables => [],
        :expected_response_from     => "Scheduler usage <test@test.com>",
        :expected_response_subject  => "RE: my availability -- invalid syntax",
        :expected_response_matchers => [/You must specify your availability in the body of the email/]            
      },
      
      :bad_timezone_offset => {
        :email   => 'snoopymcbeagle@example.com',
        :from    => 'Sal <snoopymcbeagle@example.com>',
        :to      => 'test+list.event-avail-1@test.com',
        :subject => 'my availability',
        :body    => ['   UTC',
                   'Mon Wed Fri', 
                   '12:30pm - 20:00'].join("\r\n"),
        :list_id => 'list',
        :expected_availables => [],
        :expected_response_from     => "Scheduler usage <test@test.com>",
        :expected_response_subject  => "RE: my availability -- invalid syntax",
        :expected_response_matchers => []            
      },    
      
      :nonformatted_body => {
        :email   => 'snoopymcbeagle@example.com',
        :from    => 'Sal <snoopymcbeagle@example.com>',
        :to      => 'test+list.event-avail-1@test.com',
        :subject => 'my availability',
        :body    => ['Who put the bomp in the bomp-ba-bomp-ba-bomp?',
                     'Who put the ram in the ramma-lamma-ding-dong?', 
                     '',
                     'Who put the bop',
                     'In the bop shoo bop shoo bop?'].join("\r\n"),
        :list_id => 'list',
        :expected_availables => [],
        :expected_response_from     => "Scheduler usage <test@test.com>",
        :expected_response_subject  => "RE: my availability -- invalid syntax",
        :expected_response_matchers => []            
      },      

      :no_event => {
        :email   => 'snoopymcbeagle@example.com',
        :from    => 'Sal <snoopymcbeagle@example.com>',
        :to      => 'test+list.event-avail-12345@test.com',
        :subject => 'my availability',
        :body    => ['   +09:00',
                   'Mon Wed Fri', 
                   '12:30pm - 20:00'].join("\r\n"),
        :list_id => 'list',
        :expected_availables => [],
        :expected_response_from     => "Scheduler <test@test.com>",
        :expected_response_subject  => "RE: my availability -- no event found",
        :expected_response_matchers => []      
      }
      
    }
    # -----
    
    describe 'event availability, successful cases' do
      include Helpers    
    
      before do
        reset_storage
        reset_inbox
      end

      [:basic].each do |fix|
      
        it "should update event with participant availability (#{fix})" do
          fixture = Fixtures[fix]
          
          rec = create_event_from_fixture(:dummy_event)
          event_id = rec.id
          
          subscribers = [fixture[:email]]
          populate_mailing_list fixture[:list_id], *subscribers
          
          process_fixture_messages fix
        
          event = event_list(fixture[:list_id]).read(event_id).contents
          refute_nil event
          
          fixture[:expected_availables].each_with_index do |expected, i|
            assert_equal expected[:days],       event.participants[0].availables[i].days
            assert_equal expected[:from],       event.participants[0].availables[i].from
            assert_equal expected[:to],         event.participants[0].availables[i].to
            assert_equal expected[:utc_offset], event.participants[0].availables[i].utc_offset
          end

        end

        it "should reply with 'confirmation' email (#{fix})" do
          fixture = Fixtures[fix]
          
          rec = create_event_from_fixture(:dummy_event)
          event_id = rec.id
          
          subscribers = [fixture[:email]]
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

    describe 'event availability, unsuccessful cases' do
      include Helpers    
    
      before do
        reset_storage
        reset_inbox
      end

      [:empty_body, :bad_timezone_offset, :nonformatted_body].each do |fix|
      
        it "should reply with 'invalid syntax' email (#{fix})" do
          fixture = Fixtures[fix]
          
          rec = create_event_from_fixture(:dummy_event)
          event_id = rec.id
          
          subscribers = [fixture[:email]]
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
    
    describe 'event availability, no such event' do
    
      include Helpers    
    
      before do
        reset_storage
        reset_inbox
      end
    
      [:no_event].each do |fix|
      
        it "should reply with 'no event' email (#{fix})" do
          fixture = Fixtures[fix]
          
          rec = create_event_from_fixture(:dummy_event)
          event_id = rec.id
          
          subscribers = [fixture[:email]]
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