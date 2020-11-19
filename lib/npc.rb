require 'random_name_generator'

class Npc
  include Entity

  attr_accessor :hp, :statuses, :resistances

  def initialize(type, opt = {})
    @properties = JSON.parse(File.read(File.join('npcs', "#{type}.json"))).deep_symbolize_keys!
    @ability_scores = @properties[:ability]
    @opt = opt
    @resistances = []
    @statuses = Set.new
    name = case(type)
    when 'goblin'
      RandomNameGenerator.new(RandomNameGenerator::GOBLIN).compose(1)
    when 'ogre'
      ['Guzar', 'Irth', 'Grukurg', 'Zoduk'].sample(1).first
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

  def reset_turn!
    @action = 1
    @bonus_action = 1
    @reaction = 1
    @movement = speed
  end

  private

  def setup_attributes
    @hp = @opt[:rand_life] ? DieRoll.roll(@properties[:hp_die]).result : @properties[:max_hp]
  end
end