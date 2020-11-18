require 'die_roll'

RSpec.describe DieRoll do
  context "die rolls" do
    specify ".roll" do
      100.times do
        expect(DieRoll.roll("1d6").result).to be_between 1, 6
      end

      100.times do
        expect(DieRoll.roll("2d6").result).to be_between 2, 12
      end

      100.times do
        expect(DieRoll.roll("2d6+2").result).to be_between 4, 14
      end

      100.times do
        expect(DieRoll.roll("2d6-1").result).to be_between 1, 14
      end

      100.times do
        expect(DieRoll.roll("2d20").result).to be_between 2, 40
      end
    end
  end
end