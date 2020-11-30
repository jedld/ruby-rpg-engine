class HelpAction < Action
  attr_accessor :target

  def build_map
    OpenStruct.new({
      action: self,
      param: [
        {
          type: :select_target,
          num: 1,
        }
      ],
      next: ->(target) {
        self.target = target
        OpenStruct.new({
          param: nil,
          next: ->() { self },
        })
      }
    })
  end

  def self.build(session, source)
    action = HelpAction.new(session, source, :help)
    action.build_map
  end

  def resolve(session, map, opts = {})
    @result = [{
      source: @source,
      target: @target,
      type: :help,
      battle: opts[:battle],
    }]
    self
  end

  def apply!
    @result.each do |item|
      case (item[:type])
      when :help
        EventManager.received_event({source: item[:source], target: item[:target], event: :help })
        item[:source].help!(item[:battle], item[:target])
      end

      item[:battle].entity_state_for(item[:source])[:action] -= 1
    end
  end
end