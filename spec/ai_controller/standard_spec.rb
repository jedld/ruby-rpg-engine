RSpec.describe AiController::Standard do
  let(:session) { Session.new }
  let(:controller) { AiController::Standard.new }

  # setup battle scenario
  # Gomerin vs a goblin and an ogre
  before do
    EventManager.clear
    EventManager.standard_cli
    @battle = Battle.new(session)
    @fighter = PlayerCharacter.load(File.join('fixtures', 'high_elf_fighter.json'))
    @npc1 = Npc.new(:goblin)
    @npc2 = Npc.new(:ogre)
    @battle.add(@fighter, :a)
    @battle.add(@npc1, :b)
    @battle.add(@npc2, :b)
    EventManager.register_event_listener([:died], ->(event) {puts "#{event[:source].name} died." })
    EventManager.register_event_listener([:unconsious], ->(event) { puts "#{event[:source].name} unconsious." })
    EventManager.register_event_listener([:initiative], ->(event) { puts "#{event[:source].name} rolled a #{event[:roll].to_s} = (#{event[:value]}) with dex tie break for initiative." })
    srand(7000)
  end

  specify "performs standard attacks" do
    @battle.start
    @battle.while_active do |entity|
      if entity == @fighter
        target = [@npc1, @npc2].select { |a| a.concious? }.first
        action = @battle.action(@fighter, :attack, target: target, using: 'vicious_rapier')
        @battle.commit(action)
      elsif entity == @npc1 || entity == @npc2
        action = controller.move_for(entity, @battle)
        @battle.action!(action)
        @battle.commit(action)
      end
    end
  end
end