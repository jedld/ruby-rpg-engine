module ItemLibrary
  class Object
    include Entity

    attr_accessor :hp, :statuses, :resistances

    def initialize(properties = {})

    end

    def opaque?
      true
    end

    def token
    end
  end
end