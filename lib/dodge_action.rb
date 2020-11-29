class DodgeAction < Action
  attr_accessor :as_bonus_action

  def build_map
    OpenStruct.new({
      param: nil,
      next: ->() { self },
    })
  end

  def self.build(session, source)
    action = DodgeAction.new(session, source, :attack)
    action.build_map
  end

  def resolve(session, map, opts = {})
    @result = [{
      source: @source,
      type: :dodge,
      battle: opts[:battle],
    }]
    self
  end

  def apply!
    @result.each do |item|
      case (item[:type])
      when :dodge
        EventManager.received_event({source: item[:source], event: :dodge })
        item[:source].dodging!(item[:battle])
      end

      if as_bonus_action
        item[:battle].entity_state_for(item[:source])[:bonus_action] -= 1
      else
        item[:battle].entity_state_for(item[:source])[:action] -= 1
      end
    end
  end
end
