module ItemLibrary
  class DoorObject < Object
    attr_reader :state, :locked, :key_name

    def opaque?
      closed? && !dead?
    end

    def unlock!
      @locked = false
    end

    def lock!
      @locked = true
    end

    def locked?
      @locked
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
      return [:unlock] if locked?

      return [] if someone_blocking_the_doorway?

      opened? ? [:close] : %i[open lock]
    end

    def resolve(entity, action)
      case action
      when :open
        if !locked?
          {
            action: action
          }
        else
          {
            action: :door_locked
          }
        end
      when :close
        {
          action: action
        }
      when :unlock
        entity.item_count(:"#{key_name}").positive? ? { action: :unlock } : { action: :unlock_failed }
      when :lock
        entity.item_count(:"#{key_name}").positive? ? { action: :lock } : { action: :lock_failed }
      end
    end

    def use!(entity, result)
      if result[:action] == :open && closed?
        open!
      elsif result[:action] == :close && opened? && someone_blocking_the_doorway?
        EventManager.received_event(source: self, user: entity, event: :object_interaction, sub_type: :close_failed, result: :failed, reason: 'Cannot close door since something is in the doorway')
      elsif result[:action] == :close && opened?
        close!
        EventManager.received_event(source: self, user: entity, event: :object_interaction, sub_type: :close, result: :success, reason: 'Door closed.')
      elsif result[:action] == :unlock && locked?
        unlock!
        EventManager.received_event(source: self, user: entity, event: :object_interaction, sub_type: :unlock, result: :success, reason: 'Door unlocked.')
      elsif result[:action] == :lock && unlocked?
        lock!
        EventManager.received_event(source: self, user: entity, event: :object_interaction, sub_type: :lock, result: :success, reason: 'Door locked.')
      elsif result[:action] == :door_locked
        EventManager.received_event(source: self, user: entity, event: :object_interaction, sub_type: :open_failed, result: :failed, reason: 'Cannot open door since door is locked.')
      elsif result[:action] == :unlock_failed
        EventManager.received_event(source: self, user: entity, event: :object_interaction, sub_type: :unlock_failed, result: :failed, reason: 'Correct Key missing.')
      end
    end

    protected

    def someone_blocking_the_doorway?
      !!map.entity_at(*position)
    end

    def on_take_damage(battle, damage_params); end

    def setup_other_attributes
      @state = @properties[:state]&.to_sym || :closed
      @locked = @properties[:locked]
      @key_name = @properties[:key]
    end
  end
end
