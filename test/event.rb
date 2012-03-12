require File.expand_path('test_helper', File.dirname(__FILE__))

module EventUnitTests

  class DummyEmail < Struct.new(:subject, :body)
        
    def text_part
      self
    end
    
    def decoded
      self.body
    end
    
  end
  
  Fixtures = [ 
  
    { :desc    => 'email has subject, date and duration specified, no defaults',
      :subject => 'A picnic | on 16-Mar-2012 | 180min',
      :body    => [''].join("\r\n"),
      :defaults => {},
      :expected_name => 'A picnic',
      :expected_duration => 180,
      :expected_range => Date.civil(2012,3,16)...Date.civil(2012,3,17),
      :expected_week  => Date.civil(2012,3,12)...Date.civil(2012,3,19)
    },
    { :desc    => 'email has subject, name and date and duration specified with whitespace, no defaults',
      :subject => '  A cooking class   | on  16-Mar-2012   |  180 min  ',
      :body    => [''].join("\r\n"),
      :defaults => {},
      :expected_name => 'A cooking class',
      :expected_duration => 180,
      :expected_range => Date.civil(2012,3,16)...Date.civil(2012,3,17),
      :expected_week  => Date.civil(2012,3,12)...Date.civil(2012,3,19)
    },
    { :desc    => 'email has subject, week and duration specified, no defaults',
      :subject => 'A symposium|week of Mar 5, 2012|840',
      :body    => [''].join("\r\n"),
      :defaults => {},
      :expected_name => 'A symposium',
      :expected_duration => 840,
      :expected_range => Date.civil(2012,3,5)...Date.civil(2012,3,12),
      :expected_week  => Date.civil(2012,3,5)...Date.civil(2012,3,12)
    },
    { :desc    => 'email has subject with "availability for", week and duration specified, no defaults',
      :subject => ' Availability for  a circus | Week of Mar 5, 2012 | 90',
      :body    => [''].join("\r\n"),
      :defaults => {},
      :expected_name => 'a circus',
      :expected_duration => 90,
      :expected_range => Date.civil(2012,3,5)...Date.civil(2012,3,12),
      :expected_week  => Date.civil(2012,3,5)...Date.civil(2012,3,12)
    }
  ]
  
  # -----
  
  describe 'Event delegates to Portera::Event' do
  
    before do
      @subject = ::Event.new { }
    end
    
    it 'should respond to participants' do
      @subject.participants
      assert true
    end
    
  end
  
  Fixtures.each do |fixture|
    describe "Event.from_email, #{fixture[:desc]}" do
    
      before do
        input = DummyEmail.new fixture[:subject], fixture[:body]
        @subject = ::Event.from_email(input, fixture[:defaults])
      end
      
      it 'should have the expected name' do
        assert_equal fixture[:expected_name], @subject.name, @subject.inspect
        # puts @subject.name
      end
      
      it 'should have the expected duration' do
        assert_equal fixture[:expected_duration], @subject.duration, @subject.inspect
        # puts @subject.duration
      end

      it 'should have the expected range' do
        assert_equal fixture[:expected_range], @subject.range, @subject.inspect
        # puts @subject.range
      end
      
      it 'should have the expected week range' do
        assert_equal fixture[:expected_week], @subject.week, @subject.inspect
        # puts @subject.week
      end
      
    end
  end
  
end