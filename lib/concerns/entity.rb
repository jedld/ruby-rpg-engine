module Entity
  def take_damage!(damage_params)
    dmg = damage_params[:damage].result
    dmg += damage_params[:sneak_attack].result unless damage_params[:sneak_attack].nil?


    dmg = (dmg / 2.to_f).floor if resistant_to?(damage_params[:damage_type])
    @hp -= dmg

    if @hp < 0 && @hp.abs >= @properties[:max_hp]
      dead!
    elsif @hp <= 0
      npc? ? dead! : unconcious!
    end
    @hp = 0 if @hp <= 0

    EventManager.received_event({ source: self, event: :damage, value: dmg })
  end

  def resistant_to?(damage_type)
    @resistances.include?(damage_type)
  end

  def dead!
    EventManager.received_event({ source: self, event: :died })
    @statuses.add(:dead)
  end

  def dead?
    @statuses.include?(:dead)
  end

  def unconcious?
    !dead? && @statuses.include?(:unconsious)
  end

  def concious?
    !dead? && !unconcious?
  end

  def entered_melee?(map, pos_x, pos_y)
    cur_x, cur_y = map.position_of(self)
    distance = Math.sqrt((cur_x - pos_x)**2 + (cur_y - pos_y)**2).ceil * 5 # one square - 5 ft

    # determine melee options
    return true if distance <= melee_distance

    false
  end

  def locate_melee_positions(map, target_position)
    result = []
    step = melee_distance / 5
    cur_x, cur_y = target_position
    (-step..step).each do |x_off|
      (-step..step).each do |y_off|
        next if x_off == 0 && y_off == 0

        # adjust melee position based on token size
        adjusted_x_off = x_off
        adjusted_y_off = y_off

        adjusted_x_off -= token_size - 1 if x_off < 0
        adjusted_y_off -= token_size - 1 if y_off < 0

        position = [cur_x + adjusted_x_off, cur_y + adjusted_y_off]

        next if position[0].negative? || position[0] >= map.size[0] || position[1].negative? || position[1] >= map.size[1]
        next unless map.passable?(self, *position)

        result << position
      end
    end
    result
  end

  def unconcious!
    EventManager.received_event({ source: self, event: :unconsious })
    @statuses.add(:unconsious)
  end

  def initiative!
    roll = DieRoll.roll("1d20+#{dex_mod}")
    value = roll.result.to_f + @ability_scores.fetch(:dex) / 100.to_f
    EventManager.received_event({ source: self, event: :initiative, roll: roll, value: value })
    value
  end

  def reset_turn!(battle)
    entity_state = battle.entity_state_for(self)
    entity_state.merge!({
                          action: 1,
                          bonus_action: 1,
                          reaction: 1,
                          movement: speed
                        })
    entity_state[:statuses].delete(:dodge)
    entity_state[:statuses].delete(:disengage)
    battle.dismiss_help_actions_for(self)
  end

  def dodging!(battle)
    entity_state = battle.entity_state_for(self)
    entity_state[:statuses].add(:dodge)
  end

  def disengage!(battle)
    entity_state = battle.entity_state_for(self)
    entity_state[:statuses].add(:disengage)
  end

  def disengage?(battle)
    entity_state = battle.entity_state_for(self)
    entity_state[:statuses]&.include?(:disengage)
  end

  def dodge?(battle)
    entity_state = battle.entity_state_for(self)
    entity_state[:statuses]&.include?(:dodge)
  end

  def help?(battle, target)
    entity_state = battle.entity_state_for(target)
    if entity_state[:target_effect]&.key?(self)
      return entity_state[:target_effect][self] == :help
    end

    false
  end

  def help!(battle, target)
    entity_state = battle.entity_state_for(target)
    entity_state[:target_effect][self] = :help
  end

  def has_action?(battle)
    (battle.entity_state_for(self)[:action].presence || 0).positive?
  end

  def total_actions(battle)
    battle.entity_state_for(self)[:action]
  end

  def total_bonus_actions(battle)
    battle.entity_state_for(self)[:bonus_action]
  end

  def available_movement(battle)
    battle.entity_state_for(self)[:movement]
  end

  def speed
    @properties[:speed]
  end

  def has_reaction?(battle)
    (battle.entity_state_for(self)[:reaction].presence || 0).positive?
  end

  def str_mod
    modifier_table(@ability_scores.fetch(:str))
  end

  def wis_mod
    modifier_table(@ability_scores.fetch(:wis))
  end

  def token_size
    square_size = size.to_sym
    case(square_size)
    when :small
      1
    when :medium
      1
    when :large
      2
    when :huge
      3
    else
      raise "invalid size #{square_size}"
    end
  end

  def int_mod
    modifier_table(@ability_scores.fetch(:int))
  end

  def dex_mod
    modifier_table(@ability_scores.fetch(:dex))
  end

  def attach_handler(event_name, callback)
    @event_handlers ||= {}
    @event_handlers[event_name.to_sym] = callback
  end

  def trigger_event(event_name, battle, session, map, event)
    @event_handlers ||= {}
    @event_handlers[event_name.to_sym]&.call(battle, session, map, event)
  end

  def deduct_ammo(ammo_type, amount = 1)
    return if @inventory[ammo_type].nil?

    qty = @inventory[ammo_type][:qty]
    @inventory[ammo_type][:qty] = qty - amount
  end

  def ammo_count(ammo_type)
    return 0 if @inventory[ammo_type].nil?

    @inventory[ammo_type][:qty]
  end

  protected

  def modifier_table(value)
    mod_table = [[1, 1, -5],
                 [2, 3, -4],
                 [4, 5, -3],
                 [6, 7, -2],
                 [8, 9, -1],
                 [10, 11, 0],
                 [12, 13, 1],
                 [14, 15, 2],
                 [16, 17, 3],
                 [18, 19, 4],
                 [20, 21, 5],
                 [22, 23, 6],
                 [24, 25, 7],
                 [26, 27, 8],
                 [28, 29, 9],
                 [30, 30, 10]]

    mod_table.each do |row|
      low, high, mod = row
      return mod if value.between?(low, high)
    end
  end
end
