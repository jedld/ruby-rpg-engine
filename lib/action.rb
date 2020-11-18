class Action
  attr_reader :action_type

  def initialize(source, action_type)
    @source = source
    @action_type = action_type
  end

  def to_s
    @action_type.to_s.humanize
  end

  def resolve(session, opts = {})
    case(action_type)
    when :attack
      target = opts[:target]
      raise "target is a required option for :attack" if target.nil?

      using = opts[:using]
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
        damage_mod = @source.attack_ability_mod(weapon)
        if @source.has_class_feature?('dueling')
          damage_mod += 2
        end
        damage_modifier = "#{weapon[:damage]}+#{damage_mod}"
        damage = DieRoll.roll(damage_modifier)
      end

      {
        attack_roll: attack_roll,
        target_ac: target.armor_class,
        hit?: hit,
        damage: damage
      }
    else
      raise "invalid action type #{action_type}"
    end
  end
end