class DashAction < MoveAction
  def self.can?(entity, battle)
    battle && entity.total_actions(battle) > 0
  end
end

class DashBonusAction < MoveAction
  def self.can?(entity, battle)
    battle && entity.class_feature?('cunning_action') && entity.total_bonus_actions(battle) > 0
  end
end