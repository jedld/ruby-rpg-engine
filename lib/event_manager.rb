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
    return if @event_listeners.nil?

    @event_listeners[event[:event]]&.each do |callable|
      callable.(event)
    end
  end

  def self.standard_cli
    EventManager.register_event_listener([:died], ->(event) {puts "#{event[:source].name&.colorize(:blue)} died." })
    EventManager.register_event_listener([:unconsious], ->(event) { puts "#{event[:source].name&.colorize(:blue)} unconsious." })
    EventManager.register_event_listener([:attacked], ->(event) {
      puts "#{event[:as_reaction] ? "Opportunity Attack: "  : ""} #{event[:source].name&.colorize(:blue)} attacked #{event[:target].name} with #{event[:attack_name]} to Hit: #{event[:attack_roll].to_s.colorize(:green)} for #{event[:value]} #{event[:damage_type]} damage."
    })
    EventManager.register_event_listener([:miss], ->(event) { puts "#{event[:as_reaction] ? "Opportunity Attack: "  : ""} rolled #{event[:attack_roll].to_s} ... #{event[:source].name&.colorize(:blue)} missed his attack #{event[:attack_name]} on #{event[:target].name}" })
    EventManager.register_event_listener([:initiative], ->(event) { puts "#{event[:source].name&.colorize(:blue)} rolled a #{event[:roll].to_s} = (#{event[:value]}) with dex tie break for initiative." })
    EventManager.register_event_listener([:move], ->(event) { puts "#{event[:source].name&.colorize(:blue)} moved #{(event[:path].size - 1) * 5}ft."})
    EventManager.register_event_listener([:dodge], ->(event) { puts "#{event[:source].name&.colorize(:blue)} takes the dodge action."})
  end
end