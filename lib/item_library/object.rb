module ItemLibrary
  class Object
    include Entity

    attr_accessor :hp, :statuses, :resistances, :name

    def initialize(properties = {})
      @name = properties[:name]
    end

    def opaque?
      true
    end

    def token
    end

    def available_actions
      []
    end
  end
end