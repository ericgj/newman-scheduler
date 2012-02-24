require 'delegate'

class Event < DelegateClass(::Portera::Event)

  def self.from_email(email, defaults={})
    parsed = Email.new(email)
    event = new(parsed.name || defaults[:name]) do
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
    
    DURATION_MATCHER = /^\s*(\d+)/
    RANGE_MATCHER    = /^\s*(week\s+of|on)\s+(.+)\s*$/i
    
    def initialize(email)
      self.raw = email
      parse_subject
      parse_body
    end
    
    private
    attr_accessor :raw
    
    def parse_subject
      self.name = raw.subject.strip unless raw.subject.empty?
    end
    
    def parse_body
      raw_lines.each do |line|
        break if self.duration && self.range
        if self.duration.nil? && DURATION_MATCHER =~ line
          self.duration = parse_duration($1)
        elsif self.range.nil? && RANGE_MATCHER =~ line
          self.range    = parse_range($2, $1.downcase)
        end
      end
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
    
    def raw_lines
      lines = raw.text_part.decoded.split("\n")
    end
    
  end
  
end
