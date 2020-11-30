module AiController
  class Standard
    attr_reader :battle_data
    def initialize
      @battle_data = {}
    end

    def register_battle_listeners(battle)
      # detects noisy things
      battle.add_battlefield_event_listener(:sound, lambda { |entity, position, stealth|

      })

      # detects line of sight movement
      battle.add_battlefield_event_listener(:movement, lambda { |entity, position|

      })
    end

    def register_handlers_on(entity)
      entity.attach_handler(:opportunity_attack, lambda { |battle, session, map, event|
        entity_x, entity_y = map.position_of(entity)
        target_x, target_y = event[:position]

        distance = Math.sqrt((target_x - entity_x)**2 + (target_y - entity_y)**2).ceil

        action = entity.available_actions(session, battle).select do |s|
          s.action_type == :attack && s.npc_action[:type] == 'melee_attack' && distance <= s.npc_action[:range]
        end.first

        if action
          action.target = event[:target]
          action.as_reaction = true
        end
        action
      })
    end

    def move_for(entity, battle)
      @battle_data[battle] ||= {}
      @battle_data[battle][entity] ||= {
        known_enemy_positions: {},
        hiding_spots: {},
        investigate_location: {}
      }

      enemy_positions = @battle_data[battle][entity][:known_enemy_positions]
      hiding_spots = @battle_data[battle][entity][:hiding_spots]
      investigate_location = @battle_data[battle][entity][:investigate_location]

      objects_around_me = battle.map.look(entity)

      my_group = battle.entity_state_for(entity)[:group]

      objects_around_me.each do |object, location|
        state = battle.entity_state_for(object)
        next unless state
        next unless object.concious?

        enemy_positions[object] = location if state[:group] != my_group
      end

      available_actions = entity.available_actions(@session)

      # generate available targets
      valid_actions = []

      if entity.has_action?(battle)
        available_actions.select { |a| a.action_type == :attack }.each do |action|
          next unless action.npc_action

          valid_targets = battle.valid_targets_for(entity, action)
          unless valid_targets.first.nil?
            action.target = valid_targets.first
            valid_actions << action
          end
        end
      end

      # movement planner
      if entity.has_action?(battle) && valid_actions.empty?
        # look for enemy
        if !enemy_positions.empty?
          path_compute = PathCompute.new(battle, battle.map, entity)
          start_x, start_y = battle.map.position_of(entity)
          to_enemy = enemy_positions.map do |k, v|
            melee_positions = entity.locate_melee_positions(battle.map, v)
            shortest_path = nil
            shortest_length = 1_000_000

            melee_positions.each do |positions|
              path = path_compute.compute_path(start_x, start_y, *positions)
              next if path.nil?

              path = path.take(entity.available_movement(battle) + 1)
              next if path.length == 1 # no route

              movement_cost = battle.map.movement_cost(entity, path, battle)
              if movement_cost < shortest_length
                shortest_path = path
                shortest_length = path.size
              end
            end
            [k, shortest_path]
          end.compact.to_h

          to_enemy.each do |_, path|
            next if path.nil? || path.empty?

            move_action = MoveAction.new(battle.session, entity, :move)
            if entity.available_movement(battle).zero?
              move_action.as_dash = true
            end
            move_action.move_path = path
            valid_actions << move_action
          end
        end
      end

      if entity.has_action?(battle)
        valid_actions << DodgeAction.new(battle.session, entity, :dodge)
      end

      return valid_actions.first unless valid_actions.empty?
    end
  end
end
