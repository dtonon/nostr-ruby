class Context
  attr_reader :canceled, :timeout

  def initialize(timeout: nil)
    @timeout = timeout
    @canceled = false
    @mutex = Mutex.new
    @condition = ConditionVariable.new

    # Start a timer if a timeout is specified
    if @timeout
      @start_time = Time.now
    end
  end

  def cancel
    @mutex.synchronize do
      @canceled = true
      @condition.broadcast
    end
  end

  def timed_out?
    return false unless @timeout

    # Check the elapsed time without locking the mutex
    Time.now - @start_time > @timeout
  end

  def wait(&block)
    reset # Reset the context state before waiting
    loop do
      break if block.call
      if timed_out?
        raise StandardError.new("Operation timed out after #{timeout} seconds")
      end
      sleep(0.1) # Sleep briefly to avoid busy-waiting
    end
  end

  def reset
    @mutex.synchronize do
      @canceled = false
      @start_time = Time.now if @timeout
    end
  end

end
