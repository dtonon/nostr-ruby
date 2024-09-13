module EventWizard
  def initialize_event_emitter
    @listeners = Hash.new { |hash, key| hash[key] = [] }
  end

  def on(event, &callback)
    # Prevent adding the same callback multiple times
    unless @listeners[event].include?(callback)
      @listeners[event] << callback
    end
  end

  def emit(event, *args)
    @listeners[event].each { |callback| callback.call(*args) }
  end

  def off(event, callback)
    return unless @listeners[event]
    @listeners[event].delete(callback)
  end

  def replace(event, old_callback, new_callback)
    return unless @listeners[event]
    index = @listeners[event].index(old_callback)
    @listeners[event][index] = new_callback if index
  end

  def clear(event)
    @listeners.delete(event)
  end
end