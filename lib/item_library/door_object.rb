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

      pos_x, pos_y = position
      t = if map.wall?(pos_x - 1, pos_y) || map.wall?(pos_x + 1, pos_y)
            opened? ? '-' : '='
          else
            opened? ? '|' : '║'
          end

      [t]
    end

    def token_opened
      @properties[:token_open].presence || '-'
    end

    def token_closed
      @properties[:token_closed].presence || '='
    end

    def available_actions
      return [] if someone_blocking_the_doorway?

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

    def someone_blocking_the_doorway?
      !!map.entity_at(*position)
    end

    def on_take_damage(battle, damage_params); end

    def setup_other_attributes
      @state = @properties[:state]&.to_sym || :closed
    end
  end
end
