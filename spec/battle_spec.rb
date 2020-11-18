RSpec.describe Battle do
  let(:session) { Session.new }
  context "Simple Battle" do
    before do
      @battle = Battle.new(session)
      @fighter = PlayerCharacter.load(File.join('fixtures', 'high_elf_fighter.json'))
      @npc = Npc.new(:goblin)
      @battle.add(@fighter)
      @battle.add(@npc)
      srand(7000)
    end

    specify "attack" do
      expect(@battle.action(@fighter, :attack, target: @npc, using: 'vicious_rapier').to_json).to eq("{\"attack_roll\":{\"rolls\":[2],\"modifier\":8},\"target_ac\":15,\"hit?\":false,\"damage\":null}")
      expect(@battle.action(@fighter, :attack, target: @npc, using: 'vicious_rapier').to_json).to eq("{\"attack_roll\":{\"rolls\":[14],\"modifier\":8},\"target_ac\":15,\"hit?\":true,\"damage\":{\"rolls\":[8],\"modifier\":7}}")
    end
  end
end