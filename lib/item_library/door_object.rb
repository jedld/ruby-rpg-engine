module ItemLibrary
  attr_reader :state

  class DoorObject < Object
    def initialize(properties = {})
      @state = properties[:state]&.to_sym || :closed
      @name = properties[:name]
    end

    def opaque?
      closed?
    end

    def closed?
      @state == :closed
    end

    def opened?
      @state == :opened
    end

    def open!
      @state = :opened
    end

    def close!
      @state = :closed
    end

    def token
      opened? ? '-' : '='
    end

    def available_actions
      opened? ? [:close] : [:open]
    end

    def resolve(action)
      case action
      when :open
        {
          action: action
        }
      when :close
        {
          action: action
        }
      end
    end

    def use!(_entity, result)
      if result[:action] == :open && closed?
        open!
      elsif result[:action] == :close && opened?
        close!
      end
    end
  end
end
