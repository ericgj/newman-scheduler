# nearly identical to Newman::Record, but elements indexed via explicit key 
# instead of array index
module Newman
  #Record = Struct.new(:column, :id, :contents)

  class KeyRecorder
    include Enumerable

    def initialize(column, store)
      self.column = column
      self.store  = store

      unless store.read { |data| data[:columns][column] }
        store.write do |data|
          data[:columns][column]     ||= Hash.new{|h,k| h={}}
        end
      end
    end


    def each
      store.read do |data|
        data[:columns][column].each do |id, contents| 
          yield(Record.new(column, id, contents)) 
        end
      end
    end

    def create(key, contents)
      store.write do |data| 
        
        data[:columns][column][key] = contents 

        Record.new(column, key, contents)
      end
    end


    def read(key)
      store.read do |data|
        Record.new(column, key, data[:columns][column][key])
      end
    end


    def update(key)
      store.write do |data|
        data[:columns][column][key] = yield(data[:columns][column][key])

        Record.new(column, key, data[:columns][column][key])
      end
    end
    
    def destroy(key)
      store.write do |data|
        data[:columns][column].delete(key)
      end

      true
    end

    private
    attr_accessor :column, :store
  end
end