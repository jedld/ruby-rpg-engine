module Multiattack
  attr_accessor :total_attacks

  def setup_attributes
    super

    return unless class_feature?('multiattack')

    @total_attacks = 0
  end
end
