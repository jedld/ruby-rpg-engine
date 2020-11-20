class DieRoll
  attr_reader :rolls, :modifier, :die_sides

  def initialize(rolls, modifier, die_sides = 20)
    @rolls = rolls
    @modifier = modifier
    @die_sides = die_sides
  end

  def nat_20?
    @rolls.include?(20)
  end

  def nat_1?
    @rolls.include?(1)
  end

  def result
    @rolls.sum + @modifier
  end

  def to_s
    rolls = @rolls.map do |r|
      if r == 1
        r.to_s.colorize(:red)
      elsif r == @die_sides
        r.to_s.colorize(:green)
      else
        r.to_s
      end
    end # colorize

    "(#{rolls.join(' + ')}) + #{@modifier}"
  end

  def self.numeric?(c)
    return true if c =~ /\A\d+\Z/
    true if Float(c) rescue false
  end

  def ==(other_object)
    return true if other_object.rolls == @rolls && other_object.modifier == @modifier && other_object.die_sides == @die_sides

    false
  end

  def self.roll(roll_str, crit: false)
    state = :initial
    number_of_die = 1
    die_sides = 20

    die_count_str = ""
    die_type_str = ""
    modifier_str = ""
    modifier_op = ''
    roll_str.strip.each_char do |c|
      case state
      when :initial
        if numeric?(c)
          die_count_str << c
        elsif c == 'd'
          state = :die_type
        end
      when :die_type
        next if c == ' '

        if numeric?(c)
          die_type_str << c
        elsif c == '+'
          state = :modifier
        elsif c == '-'
          modifier_op = '-'
          state = :modifier
        end
      when :modifier
        next if c == ' '

        if numeric?(c)
          modifier_str << c
        end
      end
    end
    number_of_die = die_count_str.blank? ? 1 : die_count_str.to_i
    die_sides = die_type_str.to_i

    if crit
      number_of_die *= 2
    end

    rolls = number_of_die.times.map do
      (1..die_sides).to_a.sample
    end

    DieRoll.new(rolls, modifier_str.blank? ? 0 : "#{modifier_op}#{modifier_str}".to_i, die_sides)
  end
end