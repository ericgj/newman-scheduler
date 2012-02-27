require 'delegate'

class Participant < DelegateClass(::Portera::Participant)

  def self.from_email(email, defaults={})
    parsed = Email.new(email)
    partic = new
    partic.name  = parsed.name  || defaults[:name]
    partic.email = parsed.email || defaults[:email]
    partic.range = parsed.range  || defaults[:range]
    partic.available( parsed.utc_offset || defaults[:utc_offset] ) do
      parsed.availables.each do |avail|
        on avail.days, :from => avail.from, :to => avail.to
      end
    end
    partic
  end
  
  # the week range this participant/availability defines
  attr_accessor :range
  
  def initialize(*args)
    super(::Portera::Participant.new(*args))
  end
  
  # Internal parser class for extracting participant/availability data from 
  # mail message
  class Email
  
    attr_accessor :name, :email, :utc_offset, :range, :availables
    
    Available = Struct.new(:days, :from, :to)
    
    RANGE_MATCHER      = /^\s*([^\s]+)/i
    OFFSET_MATCHER     = /([\-\+\d\:]+)\s*$/i
    TIME_RANGE_MATCHER = /^\s*([^\s]+)\s*\-\s*([^\s]+)\s*$/i
    
    def initialize(email)
      self.raw = email
      self.availables = []
      parse_from
      parse_subject
      parse_body
    end
    
    private
    attr_accessor :raw
    
    def parse_from
      self.email = raw.from.first.to_s
      self.name  = raw[:from].display_names.first
    end
    
    def parse_subject
      if RANGE_MATCHER =~ raw.subject
        parse_range $1
      else
        parse_range raw.date.to_s
      end
      if OFFSET_MATCHER =~ raw.subject
        parse_offset $1
      else
        parse_offset 'UTC'
      end
    end
    
    def parse_body
      state = nil
      raw_lines.inject([]) do |current_days, line|
        clean_line = line.chomp.strip
        if clean_line.empty?
          state = nil; next []
        end
        case state
        when nil
          parse_available_days(clean_line) do |days|
            current_days = days
          end
          state = :times
        when :times
          avail = Available.new
          avail.days = current_days.dup
          parse_available_times(clean_line) do |from, to|
            avail.from = from
            avail.to   = to
          end
          self.availables << avail
        end
        current_days
      end  
    end
    
    def parse_range(dtexpr)
      dt = Time.parse(dtexpr) rescue nil
      unless dt
        self.range = nil; return
      end
      monday = dt.to_date + (1 - (dt.to_date.wday%7))
      self.range = monday...(monday+7)
    end
    
    def parse_offset(offexpr)
      self.utc_offset = offexpr
    end

    def parse_available_days(text)
      days = text.split(/\s+/).map(&:to_sym)
      block_given? ? yield(days) : days
    end
    
    def parse_available_times(text)
      if TIME_RANGE_MATCHER =~ text
        block_given? ? yield($1,$2) : [$1,$2]
      end
    end
    
    def raw_lines
      if raw.body.multipart?
        raw.text_part
      else
        raw
      end.decoded.split("\n")
    end

  end
  
end