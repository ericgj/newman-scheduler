require File.expand_path('test_helper', File.dirname(__FILE__))

module ParticipantUnitTests

  class DummyEmail < Struct.new(:from, :display_name, :date, :subject, :body)
        
    def initialize(*args)
      super
      self.from = Array(self.from)
      self.body.extend( Module.new { def multipart?; false; end } )
    end
    
    def display_names
      [self.display_name]
    end
    
    def [](key)
      self
    end
    
    def text_part
      self
    end
    
    def decoded
      self.body
    end
    
  end
  
  

  Fixtures = [ 
  
    { :desc    => 'email has subject and body, date and offset specified, one set of availability',
      :from    => 'qbert@hello.com',
      :display_name => 'Dr. Quinn',
      :date    => Time.parse("Sun Mar 11 14:13 +09:00 2012"),
      :subject => '12-Mar-2012  +09:00',
      :body    => ['Mon Wed Fri', 
                   '12:30pm - 20:00'].join("\r\n"),
      :defaults => {},
      :expected_name   => 'Dr. Quinn',
      :expected_email  => 'qbert@hello.com',
      :expected_range  => Date.civil(2012,3,12)...Date.civil(2012,3,19),
      :expected_availables => [
        {:days => [1,3,5], :from => '12:30pm', :to => '20:00', :utc_offset => '+09:00'}
      ]
    },
    
    { :desc    => 'email has subject and body, date and offset specified, two sets of available dates',
      :from    => 'raj@boom.com',
      :display_name => 'Rufus Jones',
      :date    => Time.parse("Sun Mar 11 14:13 +09:00 2012"),
      :subject => '12-Mar-2012  +09:00',
      :body    => ['mon wed fri', 
                   '12:30pm - 20:00', 
                   '',
                   'Tuesday Thursday',
                   '10:00   - 15:15'].join("\r\n"),
      :defaults => {},
      :expected_name   => 'Rufus Jones',
      :expected_email  => 'raj@boom.com',
      :expected_range  => Date.civil(2012,3,12)...Date.civil(2012,3,19),
      :expected_availables => [
        {:days => [1,3,5], :from => '12:30pm', :to => '20:00', :utc_offset => '+09:00'},
        {:days => [2,4],   :from => '10:00',   :to => '15:15', :utc_offset => '+09:00'}
      ]
    },
    
    { :desc    => 'email has subject and body, date and offset specified, three sets of available times',
      :from    => 'sassy@example.net',
      :display_name => 'Siddhartha',
      :date    => Time.parse("Sun Mar 11 14:13 -08:00 2012"),
      :subject => '12-Mar-2012  -08:00',
      :body    => ['  mon   wed  fri ', 
                   '12:30pm   - 20:00  ', 
                   '21:30 -  22:00', 
                   '  23:20 - 00:30' 
                  ].join("\r\n"),
      :defaults => {},
      :expected_name   => 'Siddhartha',
      :expected_email  => 'sassy@example.net',
      :expected_range  => Date.civil(2012,3,12)...Date.civil(2012,3,19),
      :expected_availables => [
        {:days => [1,3,5], :from => '12:30pm', :to => '20:00', :utc_offset => '-08:00'},
        {:days => [1,3,5], :from => '21:30',   :to => '22:00', :utc_offset => '-08:00'},
        {:days => [1,3,5], :from => '23:20',   :to => '00:30', :utc_offset => '-08:00'}        
      ]
    },
    
    { :desc    => 'email has subject and body, date and offset specified, multple sets of availability',
      :from    => 'tiger@golf.com',
      :display_name => 'T. Woods',
      :date    => Time.parse("Sun Mar 11 14:13 -08:00 2012"),
      :subject => ' 12-Mar-2012  UTC',
      :body    => ['  ',
                   '  mon   wed  fri ', 
                   '1:00pm   - 2:00pm  ', 
                   '3:30pm -  4:30pm', 
                   '  8:20pm - 10:30pm',
                   '  ',
                   '',                   
                   'Tue sat',
                   '10:00   - 15:15',
                   '17:15  - 19:30',
                   ''
                  ].join("\r\n"),
      :defaults => {},
      :expected_name   => 'T. Woods',
      :expected_email  => 'tiger@golf.com',
      :expected_range  => Date.civil(2012,3,12)...Date.civil(2012,3,19),
      :expected_availables => [
        {:days => [1,3,5], :from => '1:00pm', :to => '2:00pm',  :utc_offset => 'UTC'},
        {:days => [1,3,5], :from => '3:30pm', :to => '4:30pm',  :utc_offset => 'UTC'},
        {:days => [1,3,5], :from => '8:20pm', :to => '10:30pm', :utc_offset => 'UTC'},
        {:days => [2,6],   :from => '10:00',  :to => '15:15',   :utc_offset => 'UTC'},
        {:days => [2,6],   :from => '17:15',  :to => '19:30',   :utc_offset => 'UTC'}        
      ]
    }    
  ]
  
  # ------
  
  Fixtures.each do |fixture|
    describe "Participant.from_email, #{fixture[:desc]}" do
    
      before do
        input = DummyEmail.new fixture[:from], fixture[:display_name], 
                               fixture[:date], fixture[:subject], fixture[:body]
        @subject = ::Participant.from_email(input, fixture[:defaults])
      end
      
      it 'should have the expected name' do
        assert_equal fixture[:expected_name], @subject.name, @subject.inspect
        # puts @subject.name
      end
      
      it 'should have the expected email' do
        assert_equal fixture[:expected_email], @subject.email, @subject.inspect
        # puts @subject.email
      end

      it 'should have the expected range' do
        assert_equal fixture[:expected_range], @subject.range, @subject.inspect
        # puts @subject.range
      end
      
      it 'should have the expected number of availabilities' do
        assert_equal fixture[:expected_availables].count, 
                     @subject.availables.count, @subject.inspect
      end
      
      it 'should have the expected availabilities' do
        fixture[:expected_availables].each_with_index do |expected, i|
          assert_equal expected[:days],       @subject.availables[i].days
          assert_equal expected[:from],       @subject.availables[i].from
          assert_equal expected[:to],         @subject.availables[i].to
          assert_equal expected[:utc_offset], @subject.availables[i].utc_offset
        end
      end
      
    end
  end
    
end