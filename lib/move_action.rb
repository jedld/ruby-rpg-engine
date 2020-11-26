class MoveAction < Action
  attr_accessor :move_path

  def build_map
    OpenStruct.new({
      action: self,
      param: [
        {
          type: :movement
        },
      ],
      next: ->(path) {
        self.move_path = path
        OpenStruct.new({
          param: nil,
          next: ->() { self },
        })
      },
    })
  end

  def self.build(session, source)
    action = MoveAction.new(session, source, :attack)
    action.build_map
  end

  def resolve(session, map, opts = {})
    raise "no path specified" if move_path.nil? || move_path.empty?

    # check for melee opportunity attacks
    battle = opts[:battle]

    if battle
      opportunity_attacks = opportunity_attack_list(battle, map)
      opportunity_attacks.each do |enemy_opporunity|
        next unless enemy_opporunity[:source].has_reaction?

        original_location = move_path[enemy_opporunity[:path] - 1]
        battle.trigger_opportunity_attack(enemy_opporunity[:source], @source, *original_location)
      end
    end

    @result = [{
      source: @source,
      map: map,
      battle: battle,
      type: :move,
      path: move_path,
      position: move_path.last
    }]
  end

  def opportunity_attack_list(battle, map)
    # get opposing forces
    opponents = battle.opponents_of?(@source)
    entered_melee_range = Set.new
    left_melee_range = []
    move_path.each_with_index do |path, index|
      opponents.each do |enemy|
        entered_melee_range.add(enemy) if enemy.entered_melee?(map, *path)
        left_melee_range << { source: enemy, path: index } if !left_melee_range.include?(enemy) && entered_melee_range.include?(enemy) && !enemy.entered_melee?(map, *path)
      end
    end
    left_melee_range
  end

  def apply!
    @result.each do |item|
      case (item[:type])
      when :move
        EventManager.received_event({ source: item[:source], position: item[:position], path: item[:path] })
        item[:map].move_to!(item[:source], *item[:position])
        item[:battle].entity_state_for(item[:source])[:movement] -= (item[:path].length - 1) * 5 if item[:battle]
      end
    end
  end
end