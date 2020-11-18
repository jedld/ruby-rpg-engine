class PlayerCharacter
  class Action
    def initialize(source, action_type)
      @source = source
      @action_type = action_type
    end

    def to_s
      @action_type.to_s.humanize
    end
  end

  attr_accessor :hp, :statuses

  def initialize(properties, class_properties)
    @properties = properties.deep_symbolize_keys!
    @ability_scores = @properties[:ability]
    @class_properties = class_properties
    @equipped = @properties[:equipped]
    @race_properties = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'races', "#{@properties[:race]}.yml")).deep_symbolize_keys!
    @statuses = []
    setup_attributes
    reset_turn!
  end

  def name
    @properties[:name]
  end

  def armor_class
    equiped_ac + dex_mod
  end

  def level
    @properties[:level]
  end

  def speed
    @race_properties[:base_speed]
  end

  def c_class
    @properties[:class]
  end

  def str_mod
    modifier_table(@ability_scores.fetch(:str))
  end

  def wis_mod
    modifier_table(@ability_scores.fetch(:wis))
  end

  def int_mod
    modifier_table(@ability_scores.fetch(:int))
  end

  def dex_mod
    modifier_table(@ability_scores.fetch(:dex))
  end

  def passive_perception
    10 + wis_mod + wisdom_proficiency
  end

  def passive_investigation
    10 + int_mod + investigation_proficiency
  end

  def passive_insight
    10 + wis_mod + insight_proficiency
  end

  def wisdom_proficiency
    perception_proficient? ? proficiency_bonus : 0
  end

  def investigation_proficiency
    investigation_proficient? ? proficiency_bonus : 0
  end

  def insight_proficiency
    insight_proficient? ? proficiency_bonus : 0
  end

  def proficiency_bonus
    @class_properties[:proficiency_bonuses][level - 1]
  end

  def perception_proficient?
    @properties[:skills].include?('perception')
  end

  def investigation_proficient?
    @properties[:skills].include?('investigation')
  end

  def insight_proficient?
    @properties[:skills].include?('insight')
  end

  def to_h
    {
      name: name,
      class: c_class,
      hp: hp,
      ability: {
        str: @ability_scores.fetch(:str),
        dex: @ability_scores.fetch(:dex),
        con: @ability_scores.fetch(:con),
        int: @ability_scores.fetch(:int),
        wis: @ability_scores.fetch(:wis),
        cha: @ability_scores.fetch(:cha)
      },
      passive: {
        perception: passive_perception,
        investigation: passive_investigation,
        insight: passive_insight
      }
    }
  end

  def available_actions
    [:attack, :move, :dash].map { |type|
      Action.new(self, type)
    }
  end

  def reset_turn!
    @action = 1
    @bonus_action = 1
    @reaction = 1
    @movement = speed
  end

  private

  def setup_attributes
    @hp = @properties[:max_hp]
  end

  def equiped_ac
    @equipments ||= YAML.load_file(File.join(File.dirname(__FILE__), '..', 'items', 'equipment.yml')).deep_symbolize_keys!

    equipped_meta = @equipped.map { |e| @equipments[e.to_sym] }.compact
    armor = equipped_meta.detect do |equipment|
              equipment[:type] == 'armor'
            end

    shield = equipped_meta.detect { |e| e[:type] == 'shield' }

    (armor.nil? ? 10 : armor[:ac]) + (shield.nil? ? 0 : shield[:bonus_ac])
  end

  def modifier_table(value)
    mod_table = [ [1, 1, -5],
      [2, 3, -4],
      [4, 5, -3],
      [6, 7, -2],
      [8, 9, -1],
      [10, 11, 0],
      [12, 13, 1],
      [14, 15, 2],
      [16, 17, 3],
      [18, 19, 4],
      [20, 21, 5],
      [22, 23, 6],
      [24, 25, 7],
      [26, 27, 8],
      [28, 29, 9],
      [30, 30, 10]
    ]

    mod_table.each do |row|
      low, high, mod = row
      return mod if value.between?(low, high)
    end
  end
end