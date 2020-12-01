module FighterClass
  attr_accessor :fighter_level, :second_wind_count, :second_wind_max

  def second_wind_die
    "1d10+#{@fighter_level}"
  end
end