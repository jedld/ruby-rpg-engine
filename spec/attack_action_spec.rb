RSpec.describe AttackAction do
  let(:session) { Session.new }
  before do
    @battle = Battle.new(session)
    @fighter = PlayerCharacter.load(File.join("fixtures", "high_elf_fighter.json"))
    @npc = Npc.new(:goblin)
  end

  it "auto build" do
    cont = AttackAction.build(session, @fighter)
    begin
      param = cont.param&.map { |p|
        case (p[:type])
        when :select_target
          @npc
        when :select_weapon
          "vicious_rapier"
        else
          raise "unknown #{p.type}"
        end
      }
      cont = cont.next.call(*param)
    end while !param.nil?
    expect(cont.target).to eq(@npc)
    expect(cont.source).to eq(@fighter)
    expect(cont.using).to eq("vicious_rapier")
  end
end
