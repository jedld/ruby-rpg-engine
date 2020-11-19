class Action
  attr_reader :action_type, :result

  def initialize(source, action_type, opts = {})
    @source = source
    @action_type = action_type
    @result = []
    @opts = {}
  end

  def to_s
    @action_type.to_s.humanize
  end

  def label
    if @action_type == :attack
     "#{@action_type.to_s.humanize} with #{opts[:with][:name]}"
    else
      action_type.to_s.humanize
    end
  end

  def apply!
    @result.each do |item|
      case(item[:type])
      when :damage
        item[:target].take_damage!(item)
      end
    end
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

        damage_mod += 2 if @source.has_class_feature?('dueling')

        damage_modifier = "#{weapon[:damage]}+#{damage_mod}"
        damage = DieRoll.roll(damage_modifier, crit: attack_roll.nat_20?)
      end

      if hit
        @result = [{
          target: target,
          type: :damage,
          attack_roll: attack_roll,
          target_ac: target.armor_class,
          hit?: hit,
          damage: damage
        }]
      else
        @result = [{
          target: target,
          type: :miss,
          attack_roll: attack_roll
        }]
      end

      self
    else
      raise "invalid action type #{action_type}"
    end
  end
end