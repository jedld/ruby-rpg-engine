class Battle
  def initialize(session)
    @session = session
    @entities = Set.new
  end

  def add(entity)
    @entities << entity
  end

  def action(source, action_type, opts = {})
    action = source.available_actions.detect { |act| act.action_type == action_type }
    if action
      action.resolve(@session, opts)
    end
  end
end