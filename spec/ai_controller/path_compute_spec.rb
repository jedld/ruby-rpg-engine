RSpec.describe AiController::PathCompute do
  let(:session) { Session.new }
  before do
    String.disable_colorization true
    @map = BattleMap.new(session, 'fixtures/path_finding_test')
    @fighter = PlayerCharacter.load(File.join('fixtures', 'high_elf_fighter.json'))
    @path_compute = AiController::PathCompute.new(nil, @map, @fighter)
  end

  specify 'compute' do
    expect(@map.render).to eq("········\n" +
                              "····#···\n" +
                              "···##···\n" +
                              "····#···\n" +
                              "········\n" +
                              "·######·\n" +
                              "········\n")
    expect(@path_compute.compute_path(0, 0, 6, 6)).to eq([[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 4], [6, 4], [7, 5], [6, 6]])
    expect(@map.render(path: @path_compute.compute_path(0, 0, 6, 6))).to eq("X·······\n" +
      "·+··#···\n" +
      "··+##···\n" +
      "···+#···\n" +
      "····+++·\n" +
      "·######+\n" +
      "······+·\n")
  end
end
