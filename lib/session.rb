require 'lib/die_roll'
require 'lib/concerns/entity'
require 'lib/action'
require 'lib/attack_action'
require 'lib/battle'
require 'lib/event_manager'
require "lib/player_character"
require "lib/npc"
require "lib/ai_controller/standard"


class Session
  def load_characters
    files = Dir[File.join(File.dirname(__FILE__), "..", "characters", "*.json") ]
    @characters ||= files.map do |file|
      char_content = JSON.parse(File.read(file))
      PlayerCharacter.new(char_content)
    end
    @characters
  end

  def load_npcs
    @npcs ||= %w[goblin ogre].map do |kind|
      Npc.new(kind, rand_life: true)
    end
  end

  def load_weapon(weapon)
    @weapons ||= YAML.load_file(File.join(File.dirname(__FILE__), '..', 'items', "weapons.yml")).deep_symbolize_keys!
    @weapons[weapon.to_sym]
  end
end