require 'forwardable'
class KeyedList
  include Enumerable
  extend Forwardable
  
  def initialize(id, store)
    store.recorder_type = Newman::KeyRecorder
    self.column = store[id]
  end
  
  def_delegators :column, :each, :create, :read, :update, :destroy
  
  private
  attr_accessor :column
    
end
