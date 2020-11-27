class MoveAction < Action
  attr_accessor :move_path, :as_dash

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
    action = MoveAction.new(session, source, :move)
    action.build_map
  end

  def resolve(session, map, opts = {})
    raise "no path specified" if (move_path.nil? || move_path.empty?) && opts[:move_path].nil?

    # check for melee opportunity attacks
    battle = opts[:battle]

    current_moves = move_path.presence || opts[:move_path]

    if as_dash
      current_moves = current_moves.take(@source.speed / 5)
    elsif (current_moves.length - 1) > @source.available_movement(battle)
      current_moves = current_moves.take(@source.available_movement(battle) + 1)
    end

    if battle
      opportunity_attacks = opportunity_attack_list(current_moves, battle, map)
      opportunity_attacks.each do |enemy_opporunity|
        next unless enemy_opporunity[:source].has_reaction?(battle)

        original_location = current_moves[enemy_opporunity[:path] - 1]
        battle.trigger_opportunity_attack(enemy_opporunity[:source], @source, *original_location)
      end
    end

    @result = [{
      source: @source,
      map: map,
      battle: battle,
      type: :move,
      path: current_moves,
      position: current_moves.last
    }]

    self
  end

  def opportunity_attack_list(current_moves, battle, map)
    # get opposing forces
    opponents = battle.opponents_of?(@source)
    entered_melee_range = Set.new
    left_melee_range = []
    current_moves.each_with_index do |path, index|
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
        EventManager.received_event({event: :move, source: item[:source], position: item[:position], path: item[:path] })
        item[:map].move_to!(item[:source], *item[:position])
        if as_dash
          item[:battle].entity_state_for(item[:source])[:action] -= 1
        else
          item[:battle].entity_state_for(item[:source])[:movement] -= (item[:path].length - 1) * 5 if item[:battle]
        end
      end
    end
  end
end