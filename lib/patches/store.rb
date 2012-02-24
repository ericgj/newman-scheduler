# monkey-patching Newman::Store to inject the recorder class
module Newman
  class Store 

    attr_accessor :recorder_type
    def recorder_type
      @recorder_type ||= Recorder
    end

    def [](column_key)
      self.recorder_type.new(column_key, self) 
    end

  end
end