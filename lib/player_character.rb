class PlayerCharacter
  include Entity
  attr_accessor :hp, :statuses, :other_counters, :resistances

  def initialize(properties)
    @properties = properties.deep_symbolize_keys!
    @ability_scores = @properties[:ability]
    @class_properties = JSON.parse(File.read(File.join(File.dirname(__FILE__), "..", "char_classes", "#{@properties[:class]}.json"))).deep_symbolize_keys!
    @equipped = @properties[:equipped]
    @race_properties = YAML.load_file(File.join(File.dirname(__FILE__), "..", "races", "#{@properties[:race]}.yml")).deep_symbolize_keys!
    @inventory = @properties[:inventory].map do |inventory|
      [inventory[:type], OpenStruct.new({ qty: inventory[:qty] })]
    end.to_h
    @statuses = Set.new
    @resistances = []
    setup_attributes
  end

  def name
    @properties[:name]
  end

  def max_hp
    @properties[:max_hp]
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
    @properties[:skills].include?("perception")
  end

  def investigation_proficient?
    @properties[:skills].include?("investigation")
  end

  def insight_proficient?
    @properties[:skills].include?("insight")
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
        cha: @ability_scores.fetch(:cha),
      },
      passive: {
        perception: passive_perception,
        investigation: passive_investigation,
        insight: passive_insight,
      },
    }
  end

  def available_actions(session, battle = nil)
    [:attack, :move, :dash, :dodge, :help, :ready, :end].map { |type|
      case (type)
      when :attack
        # check all equipped and create attack for each
        if battle.nil? || total_actions(battle) > 0
          @properties[:equipped].map do |item|
            weapon_detail = session.load_weapon(item)
            next if weapon_detail.nil?
            next unless %w[ranged_attack melee_attack].include?(weapon_detail[:type])

            action = AttackAction.new(session, self, :attack)
            action.using = item
            action
          end.compact
        end
      when :move
        if battle.nil? || available_movement(battle) > 0
          MoveAction.new(session, self, type)
        end
      else
        Action.new(session, self, type)
      end
    }.compact.flatten
  end

  def attack_roll_mod(weapon)
    modifier = attack_ability_mod(weapon)

    if proficient_with_weapon?(weapon)
      modifier += proficiency_bonus
    end

    modifier
  end

  def attack_ability_mod(weapon)
    modifier = 0

    case (weapon[:type])
    when "melee_attack"
      if weapon[:properties].include?("finesse") # if finese automatically use the largest mod
        modifier += [str_mod, dex_mod].max
      else
        modifier += str_mod
      end
    when "ranged_attack"
      modifier += dex_mod
    end

    modifier
  end

  def proficient_with_weapon?(weapon)
    @properties[:weapon_proficiencies]&.detect do |prof|
      weapon[:proficiency_type]&.include?(prof)
    end
  end

  def has_class_feature?(feature)
    @properties[:class_features]&.include?(feature)
  end

  def self.load(path)
    fighter_prop = JSON.parse(File.read(path)).deep_symbolize_keys!
    @fighter = PlayerCharacter.new(fighter_prop)
  end

  def npc?
    false
  end

  private

  def setup_attributes
    @hp = @properties[:max_hp]
  end

  def equiped_ac
    @equipments ||= YAML.load_file(File.join(File.dirname(__FILE__), "..", "items", "equipment.yml")).deep_symbolize_keys!

    equipped_meta = @equipped.map { |e| @equipments[e.to_sym] }.compact
    armor = equipped_meta.detect do |equipment|
      equipment[:type] == "armor"
    end

    shield = equipped_meta.detect { |e| e[:type] == "shield" }

    (armor.nil? ? 10 : armor[:ac]) + (shield.nil? ? 0 : shield[:bonus_ac])
  end
end
