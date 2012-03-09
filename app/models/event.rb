require 'delegate'

class Event < DelegateClass(::Portera::Event)

  def self.from_email(email, defaults={})
    parsed = Email.new(email)
    new(parsed.name || defaults[:name]) do
      duration (parsed.duration || defaults[:duration])
      range    (parsed.range || defaults[:range])
    end
  end
  
  def initialize(*args, &init)
    super(::Portera::Event.new(*args, &init))
  end
  
  # accessor for week in which start of range falls (starting on monday)
  # needed in order to match against weekly availability
  def week
    start = range.begin + (1 - (range.begin.wday%7))
    start...(start+7)
  end
  
  # Internal parser class for extracting name, duration, range from mail message
  class Email
  
    attr_accessor :name, :duration, :range
    
    FIELD_SEP        = "|"
    NAME_MATCHER     = /^\s*(Availability\s+for){0,1}\s*\b(.+)\b\s*$/i
    DURATION_MATCHER = /^\s*(\d+)/
    RANGE_MATCHER    = /^\s*(week\s+of|on)\s+\b(.+)\b\s*$/i
    
    def initialize(email)
      self.raw = email
      parse_subject
    end
    
    private
    attr_accessor :raw
    
    def parse_subject
      parts = raw.subject.strip.split(FIELD_SEP)
      self.name     = parse_name(parts[0])
      self.range    = parse_range_expr(parts[1])
      self.duration = parse_duration_expr(parts[2])
    end
    
    def parse_name(expr)
      return nil unless expr
      expr[NAME_MATCHER, 2]
    end
    
    def parse_range_expr(expr)
      return nil unless expr
      if RANGE_MATCHER =~ expr
        parse_range($2, $1.downcase)
      end
    end
    
    def parse_duration_expr(expr)
      return nil unless expr
      parse_duration expr[DURATION_MATCHER, 1]
    end
        
    def parse_duration(dur)
      self.duration = dur.to_i
    end
    
    def parse_range(dtexpr, type)
      dt = Time.parse(dtexpr) rescue nil
      return dt if dt.nil?
      case type
      when "on"
        dt.to_date...(dt.to_date+1)
      when "week of"
        dt.to_date...(dt.to_date+7)
      end
    end
    
  end
  
end
