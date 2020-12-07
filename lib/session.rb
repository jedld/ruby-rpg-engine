require 'colorize'
require 'lib/die_roll'
require 'lib/concerns/entity'
require 'lib/concerns/movement_helper'
require 'lib/actions/action'
require 'lib/concerns/fighter_class'
require 'lib/concerns/rogue_class'
require 'lib/actions/attack_action'
require 'lib/actions/dodge_action'
require 'lib/actions/help_action'
require 'lib/actions/disengage_action'
require 'lib/actions/move_action'
require 'lib/actions/dash_action'
require 'lib/actions/use_item_action'
require 'lib/actions/interact_action'
require 'lib/actions/inventory_action'
require 'lib/battle'
require 'lib/utils/ray_tracer'
require 'lib/battle_map'
require 'lib/event_manager'
require 'lib/concerns/health_flavor'
require 'lib/player_character'
require 'lib/npc'
require 'lib/ai_controller/path_compute'
require 'lib/ai_controller/standard'

require 'lib/item_library/base_item'
require 'lib/item_library/healing_potion'
require 'lib/item_library/object'
require 'lib/item_library/door_object'

class Session
  def load_characters
    files = Dir[File.join(File.dirname(__FILE__), '..', 'characters', '*.yml')]
    @characters ||= files.map do |file|
      YAML.load_file(file)
    end
    @characters.map do |char_content|
      PlayerCharacter.new(char_content)
    end
  end

  def load_npcs
    %w[goblin ogre].map do |kind|
      Npc.new(kind, rand_life: true)
    end
  end

  def self.load_weapon(weapon)
    @weapons ||= YAML.load_file(File.join(File.dirname(__FILE__), '..', 'items', 'weapons.yml')).deep_symbolize_keys!
    @weapons[weapon.to_sym]
  end

  def self.load_equipment(item)
    @equipment ||= YAML.load_file(File.join(File.dirname(__FILE__), '..', 'items', 'equipment.yml')).deep_symbolize_keys!
    @equipment[item.to_sym]
  end

  def self.load_object(object_name)
    @objects ||= YAML.load_file(File.join(File.dirname(__FILE__), '..', 'items', 'objects.yml')).deep_symbolize_keys!
    raise "cannot find #{object_name}" unless @objects.key?(object_name.to_sym)

    @objects[object_name.to_sym]
  end
end
