require 'delegate'

module Presenters
  
  class SimpleEvent < DelegateClass(Event)
    include Enumerable
    
    def initialize(event)
      super(event)
    end

    def description
      present_event
    end
    
    def best
      coalesced.best
    end
    
    def each
      best.each do |timeslot|
        yield present_time_range(timeslot.range),
              timeslot.participants.map {|p| present_participant(p)}
      end
    end
    
    # shortcut for typical case
    def minimum_participants(min=2)
      select { |timeslot, participants|
        participants.count >= min
      }
    end
      
    private
    
    def present_event
       "best times #{present_date_range(range)} (#{duration} mins)"
    end
    
    def present_date_range(r)
      if r.end - r.begin == 7
        "week of #{present_date(r.begin)}"
      else
        "between #{present_date(r.begin)} and #{present_date(r.end-1)}"
      end
    end
    
    def present_time_range(r)
      "#{present_time(r.begin)} - #{present_time(r.end)}"
    end
    
    def present_date(d)
      d.strftime("%a %-d %b")
    end
    
    def present_time(t)
      t.getutc.strftime("%l:%M%P %Z")
    end
    
    def present_participant(p)
      p.to_s
    end
        
  end
  
end