module AiController
  class Standard
    def initialize
      @battle_data = {}
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