class MoveAction < Action
  attr_accessor :move_path, :as_dash, :as_bonus_action

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

  def compute_actual_moves(current_moves, map, battle, movement_budget)
    actual_moves = []
    current_moves.each_with_index do |m, index|
      if index > 0
        if map.difficult_terrain?(@source, *m, battle)
          movement_budget -= 2
        else
          movement_budget -= 1
        end
      end

      break if movement_budget.negative?

      actual_moves << m
    end
  end

  def resolve(session, map, opts = {})
    raise "no path specified" if (move_path.nil? || move_path.empty?) && opts[:move_path].nil?

    # check for melee opportunity attacks
    battle = opts[:battle]

    current_moves = move_path.presence || opts[:move_path]

    actual_moves = []

    movement_budget = if as_dash
                        @source.speed / 5
                      else @source.available_movement(battle)
                        @source.available_movement(battle)
                      end

    actual_moves = compute_actual_moves(current_moves, map, battle, movement_budget)

    if (actual_moves.last && !map.placeable?(@source, *actual_moves.last, battle))
      actual_moves.pop
    end

    if battle && !@source.disengage?(battle)
      opportunity_attacks = opportunity_attack_list(actual_moves, battle, map)
      opportunity_attacks.each do |enemy_opporunity|
        next unless enemy_opporunity[:source].has_reaction?(battle)

        original_location = actual_moves[enemy_opporunity[:path] - 1]
        battle.trigger_opportunity_attack(enemy_opporunity[:source], @source, *original_location)

        unless @source.concious?
          actual_moves = original_location
          break
        end
      end
    end

    @result = [{
      source: @source,
      map: map,
      battle: battle,
      type: :move,
      path: actual_moves,
      position: actual_moves.last
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
        entered_melee_range.add(enemy) if enemy.entered_melee?(map, @source, *path)
        left_melee_range << { source: enemy, path: index } if !left_melee_range.include?(enemy) && entered_melee_range.include?(enemy) && !enemy.entered_melee?(map, @source, *path)
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
        if as_dash && as_bonus_action
          item[:battle].entity_state_for(item[:source])[:bonus_action] -= 1
        elsif as_dash
          item[:battle].entity_state_for(item[:source])[:action] -= 1
        else
          item[:battle].entity_state_for(item[:source])[:movement] -= item[:battle].map.movement_cost(item[:source], item[:path], item[:battle]) if item[:battle]
        end
      end
    end
  end
end