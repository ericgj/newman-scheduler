require File.expand_path('test_helper', File.dirname(__FILE__))

module ParticipantUnitTests

  class DummyEmail < Struct.new(:from, :display_name, :date, :subject, :body)
        
    def sender
      self.from
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
      :date    => Time.parse("Mon Mar 12 14:13 +09:00 2012"),
      :subject => '12-Mar-2012  +09:00',
      :body    => ['Mon Wed Fri', '12:30pm - 20:00'].join("\r\n"),
      :defaults => {},
      :expected_name   => 'Dr. Quinn',
      :expected_email  => 'qbert@hello.com',
      :expected_range  => Date.civil(2012,3,12)...Date.civil(2012,3,19),
      :expected_availables => [
        {:days => [1,3,5], :from => '12:30pm', :to => '20:00', :utc_offset => '+09:00'}
      ]
    }

  ]
  
  
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