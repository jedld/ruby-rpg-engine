class DieRoll
  attr_reader :rolls, :modifier, :die_sides

  def initialize(rolls, modifier, die_sides = 20, advantage: false, disadvantage: false)
    @rolls = rolls
    @modifier = modifier
    @die_sides = die_sides
    @advantage = advantage
    @disadvantage = disadvantage
  end

  def nat_20?
    if @advantage
      @rolls.map { |r| r.max }.detect { |r| r == 20 }
    elsif @disadvantage
      @rolls.map { |r| r.min }.detect { |r| r == 20 }
    else
      @rolls.include?(20)
    end
  end

  def nat_1?
    if @advantage
      @rolls.map { |r| r.max }.detect { |r| r == 1 }
    elsif @disadvantage
      @rolls.map { |r| r.min }.detect { |r| r == 1 }
    else
      @rolls.include?(1)
    end
  end

  def result
    sum = if @advantage
      @rolls.map { |r| r.max }.sum
    elsif @disadvantage
      @rolls.map { |r| r.min }.sum
    else
      @rolls.sum
    end

    sum + @modifier
  end

  def color_roll(r)
    if r == 1
      r.to_s.colorize(:red)
    elsif r == @die_sides
      r.to_s.colorize(:green)
    else
      r.to_s
    end
  end

  def to_s
    rolls = @rolls.map do |r|
      if @advantage
        r.map { |i|
          i == r.max ? color_roll(i) : i.to_s.colorize(:gray)
        }.join(' | ')
      elsif @disadvantage
        r.map { |i|
          i == r.min ? color_roll(i) : i.to_s.colorize(:gray)
        }.join(' | ')
      else
        color_roll(r)
      end
    end

    if (@modifier!=0)
      "(#{rolls.join(' + ')}) + #{@modifier}"
    else
      "(#{rolls.join(' + ')})"
    end
  end

  def self.numeric?(c)
    return true if c =~ /\A\d+\Z/
    true if Float(c) rescue false
  end

  def ==(other_object)
    return true if other_object.rolls == @rolls && other_object.modifier == @modifier && other_object.die_sides == @die_sides

    false
  end

  def self.roll(roll_str, crit: false, disadvantage: false, advantage: false)
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

    if state == :initial
      modifier_str = die_count_str
      die_count_str = "0"
    end

    number_of_die = die_count_str.blank? ? 1 : die_count_str.to_i
    die_sides = die_type_str.to_i

    if crit
      number_of_die *= 2
    end

    rolls = if (advantage || disadvantage)
              number_of_die.times.map { [(1..die_sides).to_a.sample, (1..die_sides).to_a.sample] }
            else
              number_of_die.times.map { (1..die_sides).to_a.sample }
            end

    DieRoll.new(rolls, modifier_str.blank? ? 0 : "#{modifier_op}#{modifier_str}".to_i, die_sides, advantage: advantage, disadvantage: disadvantage)
  end
end