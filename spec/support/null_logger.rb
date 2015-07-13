class NullLogger
  def initialize(store=nil)
    @store = store
  end

  def messages
    @store
  end

  def write(msg)
  end

  def info(msg)
    @store << msg if @store.is_a?(Array)
  end

  def debug(msg)
  end
end
