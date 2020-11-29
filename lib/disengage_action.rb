class DisengageAction < Action
  attr_accessor :as_bonus_action

  def build_map
    OpenStruct.new({
      param: nil,
      next: ->() { self },
    })
  end

  def self.build(session, source)
    action = DisengageAction.new(session, source, :attack)
    action.build_map
  end

  def resolve(_session, _map, opts = {})
    @result = [{
      source: @source,
      type: :disengage,
      battle: opts[:battle],
    }]
    self
  end

  def apply!
    @result.each do |item|
      case (item[:type])
      when :disengage
        EventManager.received_event({source: item[:source], event: :disengage })
        item[:source].disengage!(item[:battle])
      end

      if as_bonus_action
        item[:battle].entity_state_for(item[:source])[:bonus_action] -= 1
      else
        item[:battle].entity_state_for(item[:source])[:action] -= 1
      end
    end
  end
end
