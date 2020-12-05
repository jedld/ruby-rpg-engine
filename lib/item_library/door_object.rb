module ItemLibrary
  class DoorObject < Object
    attr_reader :state
    def opaque?
      closed? && !dead?
    end

    def passable?
      opened? || dead?
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
      return '`' if dead?

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

    protected

    def setup_other_attributes
      @state = @properties[:state]&.to_sym || :closed
    end
  end
end
