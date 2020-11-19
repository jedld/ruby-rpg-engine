class Battle
  attr_accessor :combat_order, :round

  def initialize(session)
    @session = session
    @entities = {}
    @battle_log = []
    @combat_order = []
    @current_turn_index = 0
    @round = 0
  end

  def add(entity)
    @entities[entity] = {}
  end

  def action(source, action_type, opts = {})
    action = source.available_actions.detect { |act| act.action_type == action_type }
    return action.resolve(@session, opts) if action

    nil
  end

  def start
    # roll for initiative
    @combat_order = @entities.map do |entity, v|
      v[:initiative] = entity.initiative!

      entity
    end

    @combat_order = @combat_order.sort_by { |a| @entities[a][:initiative] }.reverse
  end

  def current_turn
    @combat_order[@current_turn_index]
  end

  def while_active(&block)
    begin
      EventManager.received_event({source: self, event: :start_of_round, target: current_turn})
      next if current_turn.dead? || current_turn.unconcious?
      current_turn.reset_turn!

      block.call(current_turn)

      @current_turn_index += 1
      if @current_turn_index >= @combat_order.length
        @current_turn_index = 0
        @round += 1
      end

    end while(!all_dead?)
  end

  def all_dead?
    @combat_order.reject { |a| a.dead? || a.unconcious? }.empty?
  end

  def commit(action)
    return if action.nil?

    action.apply!
    @battle_log << action
  end
end