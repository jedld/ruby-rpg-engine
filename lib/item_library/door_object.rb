module ItemLibrary
  attr_reader :state

  class DoorObject < Object
    def initialize(properties = {})
      @state = properties[:state]&.to_sym || :closed
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
  end
end