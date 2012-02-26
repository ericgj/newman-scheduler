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
  
    { :desc    => 'email has subject and body, date and duration specified, no defaults',
      :subject => 'A picnic',
      :body    => ['on 16-Mar-2012', '180min'].join("\r\n"),
      :defaults => {},
      :expected_name => 'A picnic',
      :expected_duration => 180,
      :expected_range => Date.civil(2012,3,16)...Date.civil(2012,3,17),
      :expected_week  => Date.civil(2012,3,12)...Date.civil(2012,3,19)
    },
    { :desc    => 'email has subject and body, date and duration specified in reverse order, no defaults',
      :subject => 'A smorgasbord',
      :body    => ['180min','on 16-Mar-2012'].join("\r\n"),
      :defaults => {},
      :expected_name => 'A smorgasbord',
      :expected_duration => 180,
      :expected_range => Date.civil(2012,3,16)...Date.civil(2012,3,17),
      :expected_week  => Date.civil(2012,3,12)...Date.civil(2012,3,19)
    },
    { :desc    => 'email has subject and body, name and date and duration specified with whitespace, no defaults',
      :subject => '  A cooking class  ',
      :body    => ['','',' 180 min ','',' on  16-Mar-2012','','',''].join("\r\n"),
      :defaults => {},
      :expected_name => 'A cooking class',
      :expected_duration => 180,
      :expected_range => Date.civil(2012,3,16)...Date.civil(2012,3,17),
      :expected_week  => Date.civil(2012,3,12)...Date.civil(2012,3,19)
    },
    { :desc    => 'email has subject and body, week and duration specified, no defaults',
      :subject => 'A symposium',
      :body    => ['week of Mar 5, 2012','840'].join("\r\n"),
      :defaults => {},
      :expected_name => 'A symposium',
      :expected_duration => 840,
      :expected_range => Date.civil(2012,3,5)...Date.civil(2012,3,12),
      :expected_week  => Date.civil(2012,3,5)...Date.civil(2012,3,12)
    },
    { :desc    => 'email has subject and body, date specified but no duration, default 60 min',
      :subject => 'A safari',
      :body    => ['on 2012-3-16'].join("\r\n"),
      :defaults => {:duration => 60},
      :expected_name => 'A safari',
      :expected_duration => 60,
      :expected_range => Date.civil(2012,3,16)...Date.civil(2012,3,17),
      :expected_week  => Date.civil(2012,3,12)...Date.civil(2012,3,19)
    },
    { :desc    => 'email has subject and body, duration specified but no date, default today',
      :subject => 'A truffle hunt',
      :body    => ['360'].join("\r\n"),
      :defaults => {:range => Date.civil(2012,3,16)...Date.civil(2012,3,17)},
      :expected_name => 'A truffle hunt',
      :expected_duration => 360,
      :expected_range => Date.civil(2012,3,16)...Date.civil(2012,3,17),
      :expected_week  => Date.civil(2012,3,12)...Date.civil(2012,3,19)
    },
    { :desc    => 'email has subject and body, week specified but no duration, no defaults',
      :subject => 'A circus',
      :body    => ['Week of Mar 5, 2012',''].join("\r\n"),
      :defaults => {},
      :expected_name => 'A circus',
      :expected_duration => nil,
      :expected_range => Date.civil(2012,3,5)...Date.civil(2012,3,12),
      :expected_week  => Date.civil(2012,3,5)...Date.civil(2012,3,12)
    },
    { :desc    => 'email has no subject and no body, defaults specified',
      :subject => '',
      :body    => ['',''].join("\r\n"),
      :defaults => {:name => 'babysitting',
                    :duration => 60,
                    :range    => Date.civil(2012,3,5)...Date.civil(2012,3,12)},
      :expected_name => 'babysitting',
      :expected_duration => 60,
      :expected_range => Date.civil(2012,3,5)...Date.civil(2012,3,12),
      :expected_week  => Date.civil(2012,3,5)...Date.civil(2012,3,12)
    },    
    { :desc    => 'email has multiple durations and dates and weeks specified',
      :subject => 'a mosh pit',
      :body    => ['ON 16-Mar-2012', '180min','',
                   'week of Mar 5, 2012','840',
                   'on 2012-3-16','360',''].join("\r\n"),
      :defaults => {},
      :expected_name => 'a mosh pit',
      :expected_duration => 180,
      :expected_range => Date.civil(2012,3,16)...Date.civil(2012,3,17),
      :expected_week  => Date.civil(2012,3,12)...Date.civil(2012,3,19)
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