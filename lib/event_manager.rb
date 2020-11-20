class EventManager
  def self.clear
    @event_listeners = {}
  end

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

  def self.standard_cli
    EventManager.register_event_listener([:died], ->(event) {puts "#{event[:source].name} died." })
    EventManager.register_event_listener([:unconsious], ->(event) { puts "#{event[:source].name} unconsious." })
    EventManager.register_event_listener([:attacked], ->(event) { puts "#{event[:source].name} attacked #{event[:target].name} with #{event[:attack_name]} to Hit: #{event[:attack_roll].to_s} for #{event[:value]} #{event[:damage_type]} damage." })
    EventManager.register_event_listener([:miss], ->(event) { puts "rolled #{event[:attack_roll].to_s} ... #{event[:source].name} missed his attack #{event[:attack_name]} on #{event[:target].name}" })
    EventManager.register_event_listener([:initiative], ->(event) { puts "#{event[:source].name} rolled a #{event[:roll].to_s} = (#{event[:value]}) with dex tie break for initiative." })
  end
end