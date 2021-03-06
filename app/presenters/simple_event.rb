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
    
    def range
      present_date_range(super)
    end
    
    def duration
      present_duration(super)
    end
        
    def each_timeslot
      availability.each do |timeslot|
        yield present_time_range(timeslot.range),
              timeslot.participants.map {|p| present_participant(p)}      
      end
    end
    
    def each
      coalesced.best.each do |timeslot|
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
       "#{present_date_range(range)} (#{present_duration(duration)})"
    end
    
    def present_duration(n)
      min = n%60
      hr  = n/60
      if hr
        "#{hr}hr #{min}min"
      else
        "#{min}min"
      end
    end
    
    def present_date_range(r)
      if r.end - r.begin == 7
        "week of #{present_date(r.begin)}"
      else
        "between #{present_date(r.begin)} and #{present_date(r.end-1)}"
      end
    end
    
    def present_time_range(r)
      "#{present_date(r.begin)}  #{present_time(r.begin)} - #{present_time(r.end)}"
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