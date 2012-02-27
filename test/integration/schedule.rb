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
      
      def populate_mailing_list_from_fixtures(list_fix, *fixs)
        populate_mailing_list Fixtures[list_fix][:list_id],
                              *fixs.map {|f| Fixtures[f][:email] }
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
      },
      
      :schedule_list => {
        :email   => 'malcolm@example.com',
        :from    => 'malcolm@example.com',
        :to      => 'test+picnic.schedule-list@test.com',
        :subject => '',
        :body    => ''
      },
        
      :malcolm_availability => {
        :email  => 'malcolm@example.com',
        :from   => 'Malcolm Reynolds <malcolm@example.com>',
        :to     => 'test+availability@test.com',
        :subject => '12-Mar-2012',
        :body    => ['Mon wed friday',
                     ' 15:00 - 18:00  ',
                     '20:00 -  23:00',
                     '  16:00  - 19:00'].join("\r\n")             
      },

      :hoban_availability => {
        :email  => 'hoban@example.com',
        :from   => 'Hoban Washburne <hoban@example.com>',
        :to     => 'test+availability@test.com',
        :subject => '2012-03-12 +03:00',
        :body    => ['Monday Wednesday friday',
                     '18:00 - 21:00 ',
                     ' 23:00 - 02:00',
                     '18:00 -  21:30'].join("\r\n")             
      },
      
      :jayne_availability => {
        :email  => 'jcobb@example.com',
        :from   => 'Jayne Cobb <jcobb@example.com>',
        :to     => 'test+availability@test.com',
        :subject => '12/03/2012 -05:00',
        :body    => [' Mon Tue Wed   Thu  Fri ',
                     '10:00     - 13:00 ',
                     '',''].join("\r\n")             
      },

      :zoe_availability => {
        :email  => 'zw@example.com',
        :from   => 'Zoe Washburne <zw@example.com>',
        :to     => 'test+availability@test.com',
        :subject => ' Mar-12  -08:00 ',
        :body    => ['Monday Tue Thu',
                     ' 7:00 -   10:00'].join("\r\n")           
      },
      
      :inara_availability => {
        :email  => 'inaras@example.com',
        :from   => 'Inara Serra <inaras@example.com>',
        :to     => 'test+availability@test.com',
        :subject => '12-March-2012  +01:00',
        :body    => ['Mon Tue Thu',
                     '01:00 - 00:00  '].join("\r\n")
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
        @server.mailer.messages  # reset inbox
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
            assert_match matcher, response.decoded
          end
          
          assert_equal @subscribers, response.bcc
          assert_equal fixture[:expected_response_from], response.from
          assert_equal [settings.application.availability_email], 
                       response.reply_to
        end
        
      end
      
    end
    
    
    describe 'event availability' do
      include Helpers    
    
      before do
        reset_storage
        @server = server([Newman::RequestLogger, App, Newman::ResponseLogger])
        @server.mailer.messages  # reset inbox
      end
      
      it 'it should return a schedule of best times, bcc to subscribers' do
        subscriber_fixtures = [ :malcolm_availability,
                                :hoban_availability,
                                :jayne_availability,
                                :zoe_availability,
                                :inara_availability ]
        
        availability_fixtures = subscriber_fixtures.dup
        
        populate_mailing_list_from_fixtures :schedule_create, *subscriber_fixtures
                                                    
        availability_fixtures.each do |fix|
          @server.mailer.deliver_message fixture_message(fix)
        end
        @server.tick; @server.mailer.messages
        
        @server.mailer.deliver_message fixture_message(:schedule_create)
        @server.tick; @server.mailer.messages
        
        @server.mailer.deliver_message fixture_message(:schedule_list)
        @server.tick
        
        msgs = @server.mailer.messages        
        response = msgs.last
        actual = response.decoded
        
        assert_equal subscriber_fixtures.count, response.bcc.count
        
        assert_match /Mon 12 Mar\s+3\:00pm\s*UTC\s*-\s*6\:00pm\s*UTC/i, actual
        assert_match /Tue 13 Mar\s+3\:00pm\s*UTC\s*-\s*6\:00pm\s*UTC/i, actual
        assert_match /Wed 14 Mar\s+3\:00pm\s*UTC\s*-\s*6\:00pm\s*UTC/i, actual
        assert_match /Thu 15 Mar\s+3\:00pm\s*UTC\s*-\s*6\:00pm\s*UTC/i, actual
        
      end

    end
    
  end
  
  
end
