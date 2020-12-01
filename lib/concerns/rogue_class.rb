module RogueClass
  attr_accessor :rogue_level

  def sneak_attack_level
    [
      "1d6", "1d6",
      "2d6", "2d6",
      "3d6", "3d6",
      "4d6", "4d6",
      "5d6", "5d6",
      "6d6", "6d6",
      "7d6", "7d6",
      "8d6", "8d6",
      "9d6", "9d6",
      "10d6", "10d6"
    ][level]
  end
end