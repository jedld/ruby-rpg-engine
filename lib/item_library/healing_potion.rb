module ItemLibrary
  class HealingPotion < BaseItem
    def build_map(action)
      OpenStruct.new({
        param: [
          {
            type: :select_target,
            num: 1,
            range: 5
          }
        ],
        next: ->(target) {
          action.target = target
          OpenStruct.new({
            param: nil,
            next: ->() {
              action
            }
          })
        }
      })
    end

    def initialize(name, properties)
      @name = name
      @properties = properties
    end

    def consumable?
      @properties[:consumable]
    end

    def use!(battle, map, entity)
      hp_regain_roll = DieRoll.roll(@properties[:hp_regained])
      entity.heal!(hp_regain_roll.result)
    end
  end
end
