require 'random_name_generator'

class Npc
  attr_accessor :hp, :statuses

  def initialize(type, opt = {})
    @properties = JSON.parse(File.read(File.join('npcs', "#{type}.json"))).deep_symbolize_keys!
    @opt = opt
    rng = RandomNameGenerator.new(RandomNameGenerator::GOBLIN)
    @name = opt.fetch(:name, rng.compose(1))
    setup_attributes
  end

  def name
    @name
  end

  def kind
    @properties[:kind]
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
    @hp = @opt[:rand_life] ? DieRoll.roll(@properties[:hp_die]).flatten.sum : @properties[:max_hp]
  end
end