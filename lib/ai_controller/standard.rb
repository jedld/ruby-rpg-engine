module AiController
  class Standard
    def initialize
      @battle_data = {}
    end

    def register_handlers_on(entity)
      entity.attach_handler(:opportunity_attack, ->(battle, session, map, event) {
        entity_x, entity_y = map.position_of(entity)
        target_x, target_y = event[:position]

        distance = Math.sqrt((target_x - entity_x)**2 + (target_y - entity_y)**2).ceil

        action = entity.available_actions(session, battle).select { |s|
          s.action_type == :attack && s.npc_action[:type] == 'melee_attack' && distance <= s.npc_action[:range]
        }.first

        if action
          action.target = event[:target]
          action.as_reaction = true
        end
        action
      })
    end

    def move_for(entity, battle)
      @battle_data[battle] ||= {}
      @battle_data[battle][entity] ||= {}

      available_actions = entity.available_actions(@session)

      # generate available targets
      valid_actions = []
      available_actions.select { |a| a.action_type == :attack }.each do |action|
        if action.npc_action
          valid_targets = battle.valid_targets_for(entity, action)
          if !valid_targets.first.nil?
            action.target = valid_targets.first
            valid_actions << action
          end
        end
      end

      if !valid_actions.empty?
        return valid_actions.first
      end
    end
  end
end