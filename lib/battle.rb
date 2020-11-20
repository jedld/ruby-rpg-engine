class Battle
  attr_accessor :combat_order, :round

  def initialize(session)
    @session = session
    @entities = {}
    @groups = {}
    @battle_log = []
    @combat_order = []
    @current_turn_index = 0
    @round = 0
  end

  def add(entity, group)
    raise "entity cannot be nil" if entity.nil?

    @entities[entity] = { group: group }
    @groups[group] ||=  Set.new
    @groups[group].add(entity)
  end

  def entity_state_for(entity)
    @entities[entity]
  end

  def action(source, action_type, opts = {})
    action = source.available_actions(@session).detect { |act| act.action_type == action_type }
    return action.resolve(@session, opts) if action

    nil
  end

  def action!(action)
    action.resolve(@session)
  end

  # Targets that make sense for a given action
  def valid_targets_for(entity, action)
    entity_group = @entities[entity][:group]

    @entities.map do |k, prop|
      next if k == entity && action.action_type == :attack
      next if prop[:group] == entity_group
      next if entity.dead?

      k
    end.compact
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

  def while_active(max_rounds = nil, &block)
    begin
      EventManager.received_event({source: self, event: :start_of_round, target: current_turn})
      if current_turn.concious?
        current_turn.reset_turn!(self)
        block.call(current_turn)
      end

      @current_turn_index += 1
      if @current_turn_index >= @combat_order.length
        @current_turn_index = 0
        @round += 1

        return if !max_rounds.nil? && @round > max_rounds
      end

    end while(!battle_ends?)
  end

  def battle_ends?
    live_groups = @combat_order.reject { |a| a.dead? || a.unconcious? }.map { |e| @entities[e][:group] }.uniq
    live_groups.size <= 1
  end

  def commit(action)
    return if action.nil?

    action.apply!
    @battle_log << action
  end
end