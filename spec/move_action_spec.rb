RSpec.describe MoveAction do
  let(:session) { Session.new }
  before do
    @map = BattleMap.new(session, "fixtures/battle_sim")
    @battle = Battle.new(session, @map)
    @fighter = PlayerCharacter.load(File.join("fixtures", "high_elf_fighter.json"))
    @npc = Npc.new(:goblin)
    @battle.add(@fighter, :a, position: :spawn_point_1, token: "G")
    @battle.add(@npc, :b, position: :spawn_point_2, token: "g")
    @fighter.reset_turn!(@battle)
    @npc.reset_turn!(@battle)
    cont = MoveAction.build(session, @fighter)
    begin
      param = cont.param&.map { |p|
        case (p[:type])
        when :movement
          [[2,3], [2,2], [1,2]]
        else
          raise "unknown #{p.type}"
        end
      }
      cont = cont.next.call(*param)
    end while !param.nil?
    @action = cont
  end

  it "auto build" do
    @battle.action!(@action)
    @battle.commit(@action)
    expect(@map.position_of(@fighter)).to eq([1,2])
  end

  specify "#opportunity_attack_list" do
    @action.move_path = [[2,5], [3,5]]
    expect(@action.opportunity_attack_list(@battle, @map)).to eq [{ source: @npc, path: 1 }]
  end
end
