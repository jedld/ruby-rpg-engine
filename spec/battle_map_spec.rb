RSpec.describe AttackAction do
  let(:session) { Session.new }
  before do
    @battle_map = BattleMap.new(session, "fixtures/battle_sim")
    @fighter = PlayerCharacter.load(File.join("fixtures", "high_elf_fighter.json"))
    @npc = Npc.new(:goblin, name: "grok")
    @battle_map.place(0, 1, @fighter)
  end

  specify "#size" do
    expect(@battle_map.size).to eq [6, 6]
  end

  specify "#render" do
    expect(@battle_map.render).to eq "·G··#·\n" +
                                     "···##·\n" +
                                     "······\n" +
                                     "······\n" +
                                     "·##···\n" +
                                     "······\n"
  end

  context "#place" do
    specify "place tokens in the batlefield" do
      @battle_map.place(3, 3, @npc)
      expect(@battle_map.render).to eq "·G··#·\n" +
                                       "···##·\n" +
                                       "······\n" +
                                       "···g··\n" +
                                       "·##···\n" +
                                       "······\n"
    end
  end

  specify "#distance" do
    @battle_map.place(3, 3, @npc)
    expect(@battle_map.distance(@npc, @fighter)).to eq(4)
  end

  specify "#line_of_sight?" do
    expect(@battle_map.line_of_sight?(0, 0, 0, 1)).to be
    expect(@battle_map.line_of_sight?(0, 1, 0, 0)).to be
    expect(@battle_map.line_of_sight?(3, 0, 3, 2)).to_not be
    expect(@battle_map.line_of_sight?(3, 2, 3, 0)).to_not be
    expect(@battle_map.line_of_sight?(0, 0, 3, 0)).to be
    expect(@battle_map.line_of_sight?(0, 0, 5, 0)).to_not be
    expect(@battle_map.line_of_sight?(5, 0, 0, 0)).to_not be
    expect(@battle_map.line_of_sight?(0, 0, 2, 2)).to be
    expect(@battle_map.line_of_sight?(2, 0, 4, 2)).to_not be
    expect(@battle_map.line_of_sight?(4, 2, 2, 0)).to_not be
    expect(@battle_map.line_of_sight?(1, 5, 3, 0)).to_not be
    expect(@battle_map.line_of_sight?(0, 0, 5, 5)).to be
  end
end
