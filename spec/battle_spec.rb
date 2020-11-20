RSpec.describe Battle do
  let(:session) { Session.new }
  context "Simple Battle" do
    before do
      @battle = Battle.new(session)
      @fighter = PlayerCharacter.load(File.join('fixtures', 'high_elf_fighter.json'))
      @npc = Npc.new(:goblin)
      @battle.add(@fighter, :a)
      @battle.add(@npc, :b)
      EventManager.register_event_listener([:died], ->(event) {puts "#{event[:source].name} died." })
      EventManager.register_event_listener([:unconsious], ->(event) { puts "#{event[:source].name} unconsious." })
      EventManager.register_event_listener([:initiative], ->(event) { puts "#{event[:source].name} rolled a #{event[:roll].to_s} = (#{event[:value]}) with dex tie break for initiative." })
      srand(7000)
    end

    specify "attack" do
      @battle.start
      srand(7000)
      action = @battle.action(@fighter, :attack, target: @npc, using: 'vicious_rapier')
      expect(action.result).to eq([{
        attack_name: 'Vicious Rapier',
        source: @fighter,
        type: :miss,
        attack_roll: DieRoll.new([2], 8),
        target: @npc}]
      )
      action = @battle.action(@fighter, :attack, target: @npc, using: 'vicious_rapier')
      expect(action.result).to eq([{
        attack_name: "Vicious Rapier",
        type: :damage,
        source: @fighter,
        attack_roll: DieRoll.new([10], 8),
        hit?: true,
        damage: DieRoll.new([2], 7),
        damage_type: 'piercing',
        target_ac: 15,
        target: @npc
      }])
      @battle.commit(action)
      expect(@npc.hp).to eq(0)
      expect(@npc.dead?).to be
    end
  end
end