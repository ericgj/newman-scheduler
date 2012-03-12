require 'delegate'

class Participant < DelegateClass(::Portera::Participant)

  def self.from_email(email, defaults={})
    parsed = Email.new(email)
    partic = new
    partic.name  = parsed.name  || defaults[:name]
    partic.email = parsed.email || defaults[:email]
    partic.available( parsed.utc_offset || defaults[:utc_offset] ) do
      parsed.availables.each do |avail|
        on avail.days, :from => avail.from, :to => avail.to
      end
    end
    partic
  end
    
  
  attr_accessor :errors
  
  def initialize(*args)
    super(::Portera::Participant.new(*args))
    self.errors = []
  end
  
  def available(*args, &blk)
    super
  rescue => e
    errors << e.to_s
  end
  
  def valid?
    validate; errors.empty?
  end
  
  def validate
    errors << "No name specified" unless name
    errors << "No email specified" unless email
    errors << "No available times specified" unless availables.count > 0
  end
  
  
  # Internal parser class for extracting participant/availability data from 
  # mail message
  class Email
  
    attr_accessor :name, :email, :utc_offset, :availables
    
    Available = Struct.new(:days, :from, :to)
    
    OFFSET_MATCHER     = /\s*([\-\+]\d\d\:\d\d)\s*$/i
    TIME_RANGE_MATCHER = /^\s*([^\s]+)\s*\-\s*([^\s]+)\s*$/i
    
    def initialize(email)
      self.raw = email
      self.availables = []
      parse_from
      parse_body
    end
    
    private
    attr_accessor :raw
    
    def parse_from
      self.email = raw.from.first.to_s
      self.name  = raw[:from].display_names.first
    end
    
    def parse_body
      state = :init
      raw_lines.inject([]) do |current_days, line|
        clean_line = line.chomp.strip
        if clean_line.empty?
          state = nil unless state == :init; next []
        end
        case state
        when :init
          if OFFSET_MATCHER =~ clean_line
            parse_offset $1
            state = nil
          else
            parse_available_days(clean_line) do |days|
              current_days = days
            end
            state = :times
          end
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
    
    def parse_offset(offexpr)
      self.utc_offset = offexpr
    end

    def parse_available_days(text)
      days = text.split(/\s+/).delete_if {|t| t.empty?}.map(&:to_sym)
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