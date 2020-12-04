class InteractAction < Action
  attr_accessor :target, :object_action

  def self.can?(entity, battle)
    battle.nil? || entity.total_actions(battle).positive?
  end

  def self.build(session, source)
    action = InteractAction.new(session, source, :attack)
    action.build_map
  end

  def build_map
    OpenStruct.new({
                     action: self,
                     param: [
                       {
                         type: :select_object
                       }
                     ],
                     next: lambda { |object|
                             self.target = object
                             OpenStruct.new({
                                              param: [
                                                {
                                                  type: :interact,
                                                  target: object
                                                }
                                              ],
                                              next: lambda { |action|
                                                      self.object_action = action
                                                      OpenStruct.new({
                                                                       param: nil,
                                                                       next: lambda {
                                                                               self
                                                                             }
                                                                     })
                                                    }

                                            })
                           }
                   })
  end

  def resolve(_session, map = nil, opts = {})
    battle = opts[:battle]
    result_payload = {
      source: @source,
      target: target,
      object_action: object_action,
      map: map,
      battle: battle,
      type: :interact
    }.merge(target.resolve(object_action))
    @result = [result_payload]
    self
  end

  def apply!(battle)
    @result.each do |item|
      case (item[:type])
      when :interact
        EventManager.received_event({ event: :interact, source: item[:source], target: item[:target],
                                      object_action: item[:object_action] })
        item[:target].use!(item[:source], item)
        battle.entity_state_for(item[:source])[:action] -= 1 if battle
      end
    end
  end
end
