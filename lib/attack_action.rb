class AttackAction < Action
  attr_accessor :target, :using

  def to_s
    @action_type.to_s.humanize
  end

  def label
    weapon = @session.load_weapon(@opts[:using] || @using)
    attack_mod = @source.attack_roll_mod(weapon)

    "#{@action_type.to_s.humanize} with #{weapon[:name]} -> Hit: +#{attack_mod} Dmg: #{damage_modifier(weapon)}"
  end

  def apply!
    @result.each do |item|
      case(item[:type])
      when :damage
        EventManager.received_event({ source: item[:source], attack_roll: item[:attack_roll], target: item[:target], event: :attacked, damage_type: item[:damage_type], value: item[:damage].result })
        item[:target].take_damage!(item)
      when :miss
        EventManager.received_event({ attack_roll: item[:attack_roll], source: item[:source], target: item[:target], event: :miss })
      end
    end
  end

  def damage_modifier(weapon)
    damage_mod = @source.attack_ability_mod(weapon)

    damage_mod += 2 if @source.has_class_feature?('dueling')

    "#{weapon[:damage]}+#{damage_mod}"
  end

  def resolve(session, opts = {})
    target = opts[:target] || @target
    raise "target is a required option for :attack" if target.nil?

    using = opts[:using] || @using
    raise "using is a required option for :attack" if using.nil?

    weapon = session.load_weapon(using.to_sym)
    attack_mod = @source.attack_roll_mod(weapon)
    attack_roll = DieRoll.roll("1d20+#{attack_mod}")

    hit = if attack_roll.nat_20?
            true
          elsif attack_roll.nat_1?
            false
          else
            attack_roll.result >= target.armor_class
          end

    damage = nil

    if hit
      damage = DieRoll.roll(damage_modifier(weapon), crit: attack_roll.nat_20?)
    end

    if hit
      @result = [{
        source: @source,
        target: target,
        type: :damage,
        attack_roll: attack_roll,
        target_ac: target.armor_class,
        hit?: hit,
        damage_type: weapon[:damage_type],
        damage: damage
      }]
    else
      @result = [{
        source: @source,
        target: target,
        type: :miss,
        attack_roll: attack_roll
      }]
    end

    self
  end
end