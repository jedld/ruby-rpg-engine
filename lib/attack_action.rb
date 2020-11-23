class AttackAction < Action
  attr_accessor :target, :using, :npc_action

  def to_s
    @action_type.to_s.humanize
  end

  def label
    if @npc_action
      "#{@action_type.to_s.humanize} with #{npc_action[:name]}"
    else
      weapon = @session.load_weapon(@opts[:using] || @using)
      attack_mod = @source.attack_roll_mod(weapon)

      "#{@action_type.to_s.humanize} with #{weapon[:name]} -> Hit: +#{attack_mod} Dmg: #{damage_modifier(weapon)}"
    end
  end

  def self.build(session, source)
    action = AttackAction.new(session, source, :attack)
    OpenStruct.new({
      action: action,
      param: [
        {
          type: :select_target,
          num: 1,
        },
      ],
      next: ->(target) {
        action.target = target
        OpenStruct.new({
          param: [
            { type: :select_weapon },
          ],
          next: ->(weapon) {
            action.using = weapon
            OpenStruct.new({
              param: nil,
              next: ->() { action },
            })
          },
        })
      },
    })
  end

  def apply!
    @result.each do |item|
      case (item[:type])
      when :damage
        EventManager.received_event({ source: item[:source], attack_roll: item[:attack_roll], target: item[:target], event: :attacked,
                                      attack_name: item[:attack_name],
                                      damage_type: item[:damage_type],
                                      value: item[:damage].result })
        item[:target].take_damage!(item)
      when :miss
        EventManager.received_event({ attack_roll: item[:attack_roll], attack_name: item[:attack_name],
                                      source: item[:source], target: item[:target], event: :miss })
      end
    end
  end

  def damage_modifier(weapon)
    damage_mod = @source.attack_ability_mod(weapon)

    damage_mod += 2 if @source.has_class_feature?("dueling")

    "#{weapon[:damage]}+#{damage_mod}"
  end

  def resolve(session, opts = {})
    target = opts[:target] || @target
    raise "target is a required option for :attack" if target.nil?

    npc_action = opts[:npc_action] || @npc_action

    using = opts[:using] || @using
    raise "using or npc_action is a required option for :attack" if using.nil? && npc_action.nil?

    damage = nil
    attack_roll = nil
    attack_name = nil
    if npc_action
      weapon = npc_action
      attack_name = npc_action[:name]
      attack_roll = DieRoll.roll("1d20+#{npc_action[:attack]}")
      damage = DieRoll.roll(npc_action[:damage_die])
    else
      weapon = session.load_weapon(using.to_sym)
      attack_name = weapon[:name]
      attack_mod = @source.attack_roll_mod(weapon)
      attack_roll = DieRoll.roll("1d20+#{attack_mod}")
      damage = DieRoll.roll(damage_modifier(weapon), crit: attack_roll.nat_20?)
    end

    hit = if attack_roll.nat_20?
        true
      elsif attack_roll.nat_1?
        false
      else
        attack_roll.result >= target.armor_class
      end

    if hit
      @result = [{
        source: @source,
        target: target,
        type: :damage,
        attack_name: attack_name,
        attack_roll: attack_roll,
        target_ac: target.armor_class,
        hit?: hit,
        damage_type: weapon[:damage_type],
        damage: damage,
      }]
    else
      @result = [{
        attack_name: attack_name,
        source: @source,
        target: target,
        type: :miss,
        attack_roll: attack_roll,
      }]
    end

    self
  end
end
