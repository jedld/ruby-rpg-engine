class EventManager
  def self.register_event_listener(events, callable)
    @event_listeners ||= {}
    events.each do |event|
      @event_listeners[event] ||= []
      @event_listeners[event] << callable unless @event_listeners[event].include?(callable)
    end
  end

  def self.received_event(event)
    @event_listeners[event[:event]]&.each do |callable|
      callable.(event)
    end
  end
end