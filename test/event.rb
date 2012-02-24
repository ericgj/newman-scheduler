require File.expand_path('test_helper', File.dirname(__FILE__))

module EventUnitTests

  class DummyEmail < Struct.new(:subject, :body)
    
    module DummyBodyMethods
      def decoded
        self
      end
    end
    
    def initialize(*args)
      super
      self.body.extend(DummyBodyMethods)
    end
    
    def text_part
      self.body
    end
    
  end
  
  Fixtures = [ 
  
    { :desc    => 'email has subject and body, date and duration specified, no defaults',
      :subject => 'A picnic',
      :body    => ['on 16-Mar-2012', '180min'].join("\n"),
      :defaults => {},
      :expected_name => 'A picnic',
      :expected_duration => 180,
      :expected_range => Date.civil(2012,3,16)...Date.civil(2012,3,17),
      :expected_week  => Date.civil(2012,3,12)...Date.civil(2012,3,19)
    }
  
  ]
  
  Fixtures.each do |fixture|
    describe "Event.from_email, #{fixture[:desc]}" do
    
      before do
        input = DummyEmail.new fixture[:subject], fixture[:body]
        @subject = Event.from_email(input, fixture[:defaults])
      end
      
      it 'should have the expected name' do
        assert_equal fixture[:expected_name], @subject.name 
      end
      
      it 'should have the expected duration' do
        assert_equal fixture[:expected_duration], @subject.duration 
      end

      it 'should have the expected range' do
        assert_equal fixture[:expected_range], @subject.range 
      end
      
      it 'should have the expected week range' do
        assert_equal fixture[:expected_week], @subject.week
      end
      
    end
  end
  
end