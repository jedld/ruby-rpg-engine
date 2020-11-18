require 'lib/action'
require 'lib/battle'

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
    @npcs ||= %w[goblin].map do |kind|
      Npc.new(kind)
    end
  end

  def load_weapon(weapon)
    @weapons ||= YAML.load_file(File.join(File.dirname(__FILE__), '..', 'items', "weapons.yml")).deep_symbolize_keys!
    @weapons[weapon.to_sym]
  end
end