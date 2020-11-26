require "random_name_generator"

class Npc
  include Entity

  attr_accessor :hp, :statuses, :resistances

  def initialize(type, opt = {})
    @properties = JSON.parse(File.read(File.join("npcs", "#{type}.json"))).deep_symbolize_keys!
    @ability_scores = @properties[:ability]
    @opt = opt
    @resistances = []
    @statuses = Set.new
    name = case (type)
      when "goblin"
        RandomNameGenerator.new(RandomNameGenerator::GOBLIN).compose(1)
      when "ogre"
        ["Guzar", "Irth", "Grukurg", "Zoduk"].sample(1).first
      end
    @name = opt.fetch(:name, name)
    setup_attributes
  end

  def name
    @name
  end

  def kind
    @properties[:kind]
  end

  def npc?
    true
  end

  def armor_class
    @properties[:default_ac]
  end

  def speed
    @properties[:speed]
  end

  def available_actions(session, battle = nil)
    [:attack, :end].map { |type|
      if (type == :attack)
        # check all equipped and create attack for each
        @properties[:actions].map do |npc_action|
          action = AttackAction.new(session, self, :attack)
          action.npc_action = npc_action
          action
        end.compact
      else
        Action.new(session, self, type)
      end
    }.flatten
  end

  def melee_distance
    @properties[:actions].select { |a| a[:type] == 'melee_attack' }.map do |action|
      action[:range]
    end&.max
  end

  private

  def setup_attributes
    @hp = @opt[:rand_life] ? DieRoll.roll(@properties[:hp_die]).result : @properties[:max_hp]
  end
end
