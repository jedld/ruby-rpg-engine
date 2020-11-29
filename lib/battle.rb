class Battle
  attr_accessor :combat_order, :round
  attr_reader :map, :entities, :session, :battle_log

  def initialize(session, map)
    @session = session
    @entities = {}
    @groups = {}
    @battle_field_events = {}
    @battle_log = []
    @combat_order = []
    @current_turn_index = 0
    @round = 0
    @map = map
  end

  def add_battlefield_event_listener(event, handler)
    @battle_field_events[event.to_sym] ||= []
    @battle_field_events[event.to_sym] << handler
  end

  def add(entity, group, position: nil, token: nil)
    raise "entity cannot be nil" if entity.nil?

    @entities[entity] = {
      group: group,
      action: 0,
      bonus_action: 0,
      reaction: 0,
      movement: 0,
      statuses: Set.new
    }

    @groups[group] ||= Set.new
    @groups[group].add(entity)

    return if position.nil?

    position.is_a?(Array) ?@map.place(*position, entity, token) :  @map.place_at_spawn_point(position, entity, token)
  end

  def entity_state_for(entity)
    @entities[entity]
  end

  def action(source, action_type, opts = {})
    action = source.available_actions(@session).detect { |act| act.action_type == action_type }
    opts[:battle] = self
    return action.resolve(@session, @map, opts) if action

    nil
  end

  def action!(action)
    opts = {
      battle: self
    }
    action.resolve(@session, @map, opts)
  end

  # Targets that make sense for a given action
  def valid_targets_for(entity, action)
    entity_group = @entities[entity][:group]
    attack_range = if action.using
                      weapon = Session.load_weapon(action.using)
                      weapon[:range_max].presence || weapon[:range]
                    elsif action.npc_action
                      action.npc_action[:range_max].presence || action.npc_action[:range]
                    end

    @entities.map do |k, prop|
      next if k == entity && action.action_type == :attack
      next if prop[:group] == entity_group
      next if k.dead?
      next if !@map.line_of_sight_for?(entity, *@map.position_of(k))
      next if @map.distance(k, entity) * 5 > attack_range

      k
    end.compact
  end

  def opponents_of?(entity)
    source_state = entity_state_for(entity)
    source_group = source_state[:group]

    opponents = []
    @entities.each do |k, state|
      opponents << k  if !k.dead? && state[:group] != source_group
    end
    opponents
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
      EventManager.received_event({ source: self, event: :start_of_round, target: current_turn })
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
    end while (!battle_ends?)
  end

  def enemy_in_melee_range?(source)
    objects_around_me = map.look(source)

    my_group = entity_state_for(source)[:group]

    objects_around_me.detect do |object, _|
      state = entity_state_for(object)
      next unless state
      next unless object.concious?

      return true if (state[:group] != my_group && (map.distance(source, object) <= (object.melee_distance / 5)))
    end

    false
  end

  def battle_ends?
    live_groups = @combat_order.reject { |a| a.dead? || a.unconcious? }.map { |e| @entities[e][:group] }.uniq
    live_groups.size <= 1
  end

  def trigger_opportunity_attack(entity, target, cur_x, cur_y)
    event = {
      target: target,
      position: [cur_x, cur_y]
    }
    action = entity.trigger_event(:opportunity_attack, self, @session, @map, event)
    if action
      action.resolve(@session, @map, battle: self)
      commit(action)
    end
  end

  def commit(action)
    return if action.nil?

    action.apply!
    case(action.action_type)
    when :move
      trigger_event!(:movement, action.source, move_path: action.move_path)
    end
    @battle_log << action
  end

  protected

  def trigger_event!(event, source, opt = {})
    @battle_field_events[event.to_sym]&.each do |handler|
      handler.call(source, opt)
    end
  end
end
