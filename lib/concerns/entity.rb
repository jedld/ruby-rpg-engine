module Entity
  def take_damage!(damage_params)
    dmg = damage_params[:damage].result
    EventManager.received_event({ source: self, event: :damage, value: dmg })
    dmg = (dmg / 2.to_f).floor if resistant_to?(damage_params[:damage_type])
    @hp -= dmg

    if @hp < 0 && @hp.abs >= @properties[:max_hp]
      dead!
    elsif @hp <= 0
      npc? ? dead! : unconcious!
    end

    @hp = 0 if @hp <= 0
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

  def has_reaction?(battle)
    (battle.entity_state_for(self)[:reaction].presence || 0).positive?
  end

  def str_mod
    modifier_table(@ability_scores.fetch(:str))
  end

  def wis_mod
    modifier_table(@ability_scores.fetch(:wis))
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
    @event_handlers[event_name.to_sym].call(battle, session, map, event)
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
