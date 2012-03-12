# Note: run from app root dir

require File.expand_path('../test_helper', File.dirname(__FILE__))

module IntegrationTests
  module EventSched
  
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
        fixture = EventSched::Fixtures[fix]
        list_id = fixture[:list_id]
        event_list(list_id).create(fixture_event(fix))
      end
      
      def fixture_message(fix)
        fixture = EventSched::Fixtures[fix]
        {
          :from => fixture[:from],
          :to   => fixture[:to],
          :subject => fixture[:subject],
          :body    => fixture[:body]
        }
      end
      
      def fixture_event(fix)
        fixture = EventSched::Fixtures[fix]
        Event.new(fixture[:name]) do
          duration fixture[:duration]
          range    fixture[:range]
        end
      end
      
    end
    
    Fixtures = {
    
      :list => { :list_id => 'list' },  #stupidest fixture ever
      
      :dummy_event => {
        :list_id => 'list',
        :name => 'birthday party',
        :duration => 90,
        :range => Date.civil(2012,3,12)...Date.civil(2012,3,19)
      },
      
      :schedule => {
        :email  => 'hoban@example.com',
        :from  => 'hoban@example.com',
        :to    => 'test+list.event-sched-1@test.com',
        :subject => 'when can we meet?',
        :body => ''
      },
      
      :malcolm => {
        :email  => 'malcolm@example.com',
        :from   => 'Malcolm Reynolds <malcolm@example.com>',
        :to     => 'test+list.event-avail-1@test.com',
        :subject => 'my availability',
        :body    => ['Mon wed friday',
                     ' 15:00 - 18:00  ',
                     '20:00 -  23:00',
                     '  16:00  - 19:00'].join("\r\n")             
      },

      :hoban => {
        :email  => 'hoban@example.com',
        :from   => 'Hoban Washburne <hoban@example.com>',
        :to     => 'test+list.event-avail-1@test.com',
        :subject => 'my availability',
        :body    => [' +03:00 ',
                     'M W f',
                     '18:00 - 21:00 ',
                     ' 23:00 - 02:00',
                     '18:00 -  21:30'].join("\r\n")             
      },
      
      :jayne => {
        :email  => 'jcobb@example.com',
        :from   => 'Jayne Cobb <jcobb@example.com>',
        :to     => 'test+list.event-avail-1@test.com',
        :subject => 'my availability',
        :body    => ['',
                     '-05:00 ',
                     ' Mon Tue Wed   Thu  Fri ',
                     '10:00     - 13:00 ',
                     '',''].join("\r\n")             
      },

      :zoe => {
        :email  => 'zw@example.com',
        :from   => 'Zoe Washburne <zw@example.com>',
        :to     => 'test+list.event-avail-1@test.com',
        :subject => ' my availability ',
        :body    => ['',
                     '',
                     '-08:00',
                     'Monday Tue Thu',
                     ' 7:00 -   10:00',''].join("\r\n")           
      },
     
      :inara => {
        :email  => 'inaras@example.com',
        :from   => 'Inara Serra <inaras@example.com>',
        :to     => 'test+list.event-avail-1@test.com',
        :subject => 'my availability',
        :body    => ['+01:00',
                     'Mon Tue Thu',
                     '01:00 - 00:00  '].join("\r\n")
      }
      
    }
    
    # -----
    describe 'event schedule, everyones availability sent' do
      include Helpers    
    
      before do
        reset_storage
        reset_inbox
        
        create_event_from_fixture(:dummy_event)
        
        populate_mailing_list_from_fixtures :list, 
          :malcolm, :hoban, :jayne, :zoe, :inara
        
        process_fixture_messages :malcolm, :hoban, :jayne, :zoe, :inara
      end

      it 'should display best schedule with number of respondents and no footnote' do
      
        msgs = process_fixture_messages :schedule
        response = msgs.first
        body     = response.decoded
        
        assert_equal 1, msgs.count

        assert_equal [Fixtures[:schedule][:email]], 
                     response.to
                     
        assert_match(/For week of Mon 12 Mar \(1hr 30min\)/, body)
        assert_match(/5 of 5/, body)
        refute_match(/\[\*\]/, body)
        
      end
      
    end
    
    describe 'event schedule, everyones availability sent except 2' do
      include Helpers    
    
      before do
        reset_storage
        reset_inbox
        
        create_event_from_fixture(:dummy_event)
        
        populate_mailing_list_from_fixtures :list, 
          :malcolm, :hoban, :jayne, :zoe, :inara
        
        process_fixture_messages :malcolm, :jayne, :inara
      end

      it 'should display best schedule with number of respondents and footnote' do
      
        msgs = process_fixture_messages :schedule
        response = msgs.first
        body     = response.decoded
        
        assert_equal 1, msgs.count

        assert_equal [Fixtures[:schedule][:email]], 
                     response.to
                     
        assert_match(/For week of Mon 12 Mar \(1hr 30min\)/, body)
        assert_match(/3 of 5/, body)
        assert_match(/\[\*\]/, body)
        [:hoban, :zoe].each do |fix|
          assert_match(/^#{Regexp.escape(Fixtures[fix][:email])}$/, body)
        end
        
      end
      
    end

    describe 'event schedule, only one respondent' do
      include Helpers    
    
      before do
        reset_storage
        reset_inbox
        
        create_event_from_fixture(:dummy_event)
        
        populate_mailing_list_from_fixtures :list, 
          :malcolm, :hoban, :jayne, :zoe, :inara
        
        process_fixture_messages :jayne
      end

      it 'should respond with "no participants" email' do
      
        msgs = process_fixture_messages :schedule
        response = msgs.first
        body     = response.decoded
        
        assert_equal 1, msgs.count

        assert_equal [Fixtures[:schedule][:email]], 
                     response.to
                     
        refute_match(/For week of Mon 12 Mar \(1hr 30min\)/, body)
        assert_match(/less than 2 participants/, body)
        
        [:malcolm, :hoban, :zoe, :inara].each do |fix|
          assert_match(/^#{Regexp.escape(Fixtures[fix][:email])}$/, body)
        end
        
      end
      
    end
    
  end
end