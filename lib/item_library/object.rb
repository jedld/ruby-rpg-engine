module ItemLibrary
  class Object
    include Entity

    attr_accessor :hp, :statuses, :resistances, :name

    def initialize(properties = {})
      @name = properties[:name]
      @statuses = Set.new
      @properties = properties
      @resistances = properties[:resistances].presence || []
      setup_other_attributes
      @hp = DieRoll.roll(properties[:hp_die] || properties[:max_hp]).result
    end

    def armor_class
      @properties[:default_ac]
    end

    def opaque?
      true
    end

    def token
    end

    def size
      @properties[:size] || :medium
    end

    def available_actions
      []
    end

    def passable?
      false
    end

    def describe_health
      ""
    end

    def npc?
      true
    end

    protected

    def setup_other_attributes
    end
  end
end