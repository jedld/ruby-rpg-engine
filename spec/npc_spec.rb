require 'npc'

RSpec.describe Npc do
  context "goblen npc" do
    before do
      @npc = Npc.new(:goblin, name: 'Spark')
    end

    specify "#hp" do
      expect(@npc.hp).to be_between 2, 12
    end

    specify "#name" do
      expect(@npc.name).to eq 'Spark'
    end

    specify "#armor_class" do
      expect(@npc.armor_class).to eq 15
    end
  end
end