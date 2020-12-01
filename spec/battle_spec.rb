RSpec.describe Battle do
  let(:session) { Session.new }
  context "Simple Battle" do
    before do
      @map = BattleMap.new(session, "fixtures/battle_sim")
      @battle = Battle.new(session, @map)
      @fighter = PlayerCharacter.load(File.join("fixtures", "high_elf_fighter.yml"))
      @npc = Npc.new(:goblin)
      @npc2 = Npc.new(:goblin)
      @battle.add(@fighter, :a, position: :spawn_point_1, token: "G")
      @battle.add(@npc, :b, position: :spawn_point_2, token: "g")
      @battle.add(@npc2, :b, position: :spawn_point_3, token: "O")
      @fighter.reset_turn!(@battle)
      @npc.reset_turn!(@battle)
      @npc2.reset_turn!(@battle)

      EventManager.register_event_listener([:died], ->(event) { puts "#{event[:source].name} died." })
      EventManager.register_event_listener([:unconsious], ->(event) { puts "#{event[:source].name} unconsious." })
      EventManager.register_event_listener([:initiative], ->(event) { puts "#{event[:source].name} rolled a #{event[:roll].to_s} = (#{event[:value]}) with dex tie break for initiative." })
      srand(7000)
    end

    specify "attack" do
      @battle.start
      srand(7000)
      action = @battle.action(@fighter, :attack, target: @npc, using: "vicious_rapier")
      expect(action.result).to eq([{
                                 battle: @battle,
                                 attack_name: "Vicious Rapier",
                                 source: @fighter,
                                 type: :miss,
                                 attack_roll: DieRoll.new([2], 8, 20),
                                 target: @npc,
                                 npc_action: nil
                               }])
      action = @battle.action(@fighter, :attack, target: @npc, using: "vicious_rapier")
      expect(action.result).to eq([{
        attack_name: "Vicious Rapier",
        type: :damage,
        source: @fighter,
        battle: @battle,
        attack_roll: DieRoll.new([10], 8, 20),
        hit?: true,
        damage: DieRoll.new([2], 7, 8),
        damage_type: "piercing",
        target_ac: 15,
        target: @npc,
        sneak_attack: nil,
        npc_action: nil
      }])

      expect(@fighter.ammo_count("arrows")).to eq(20)
      @battle.commit(action)
      expect(@fighter.ammo_count("arrows")).to eq(20)

      expect(@npc.hp).to eq(0)
      expect(@npc.dead?).to be
      action = @battle.action(@npc2, :attack, target: @fighter, npc_action: @npc2.npc_actions[1])
      @battle.commit(action)
    end
  end
end
