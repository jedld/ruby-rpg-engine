class AttackAction < Action
  attr_accessor :target, :using, :npc_action, :as_reaction

  def to_s
    @action_type.to_s.humanize
  end

  def label
    if @npc_action
      "#{@action_type.to_s.humanize} with #{npc_action[:name]}"
    else
      weapon = Session.load_weapon(@opts[:using] || @using)
      attack_mod = @source.attack_roll_mod(weapon)

      "#{@action_type.to_s.humanize} with #{weapon[:name]} -> Hit: +#{attack_mod} Dmg: #{damage_modifier(weapon)}"
    end
  end

  def build_map
    OpenStruct.new({
      action: self,
      param: [
        {
          type: :select_target,
          num: 1,
        },
      ],
      next: ->(target) {
        self.target = target
        OpenStruct.new({
          param: [
            { type: :select_weapon },
          ],
          next: ->(weapon) {
            self.using = weapon
            OpenStruct.new({
              param: nil,
              next: ->() { self },
            })
          },
        })
      },
    })
  end

  def self.build(session, source)
    action = AttackAction.new(session, source, :attack)
    action.build_map
  end

  def apply!
    @result.each do |item|
      case (item[:type])
      when :damage
        EventManager.received_event({ source: item[:source], attack_roll: item[:attack_roll], target: item[:target], event: :attacked,
                                      attack_name: item[:attack_name],
                                      damage_type: item[:damage_type],
                                      as_reaction: as_reaction,
                                      value: item[:damage].result })
        item[:target].take_damage!(item)
      when :miss
        EventManager.received_event({ attack_roll: item[:attack_roll],
                                      attack_name: item[:attack_name],
                                      as_reaction: as_reaction,
                                      source: item[:source], target: item[:target], event: :miss })
      end

      # handle ammo
      if item[:npc_action] && item[:npc_action][:ammo]
        item[:source].deduct_ammo(item.dig(:npc_action, :ammo), 1)
      end

      if as_reaction
        item[:battle].entity_state_for(item[:source])[:reaction] -= 1
      else
        item[:battle].entity_state_for(item[:source])[:action] -= 1
      end
    end
  end

  def damage_modifier(weapon)
    damage_mod = @source.attack_ability_mod(weapon)

    damage_mod += 2 if @source.has_class_feature?("dueling")

    "#{weapon[:damage]}+#{damage_mod}"
  end

  def resolve(session, map, opts = {})
    target = opts[:target] || @target
    raise "target is a required option for :attack" if target.nil?

    npc_action = opts[:npc_action] || @npc_action
    battle = opts[:battle]
    using = opts[:using] || @using
    raise "using or npc_action is a required option for :attack" if using.nil? && npc_action.nil?

    attack_name = nil

    damage_roll = nil

    if npc_action
      weapon = npc_action
      attack_name = npc_action[:name]
      attack_mod = npc_action[:attack]
      damage_roll = npc_action[:damage_die]
    else
      weapon = Session.load_weapon(using.to_sym)
      attack_name = weapon[:name]
      attack_mod = @source.attack_roll_mod(weapon)
      damage_roll = damage_modifier(weapon)
    end

    # DnD 5e advantage/disadvantage checks
    advantage_mod = target_advantage_condition(battle, @source, target, weapon)

    # perform the dice rolls
    attack_roll = DieRoll.roll("1d20+#{attack_mod}", disadvantage: advantage_mod.negative?, advantage: advantage_mod > 0)
    damage = DieRoll.roll(damage_roll, crit: attack_roll.nat_20?)

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
        battle: battle,
        attack_name: attack_name,
        attack_roll: attack_roll,
        target_ac: target.armor_class,
        hit?: hit,
        damage_type: weapon[:damage_type],
        damage: damage,
        npc_action: npc_action
      }]
    else
      @result = [{
        attack_name: attack_name,
        source: @source,
        target: target,
        battle: battle,
        type: :miss,
        attack_roll: attack_roll,
        npc_action: npc_action
      }]
    end

    self
  end

  protected

  # Check all the factors that affect advantage/disadvantage in attack rolls
  def target_advantage_condition(battle, source, target, weapon)
    advantage = []
    advantage << -1 if target.dodge?(battle)

    if weapon[:type] == 'ranged_attack' && battle.map
      advantage << -1 if battle.enemy_in_melee_range?(source)
    end

    return 0 if advantage.empty?
    return 0 if advantage.uniq.size > 1

    advantage.first
  end
end
