class BattleMap
  attr_reader :spawn_points

  def initialize(session, map_file)
    @session = session
    @map_file = map_file
    @spawn_points = {}
    @entities = {}

    @properties = YAML.load_file(File.join(File.dirname(__FILE__), "..", "#{map_file}.yml")).deep_symbolize_keys!

    # terrain layer
    @base_map = @properties.dig(:map, :base).map do |lines|
      lines.each_char.map.to_a
    end.transpose

    # meta layer
    @meta_map = @properties.dig(:map, :meta).map do |lines|
      lines.each_char.map.to_a
    end.transpose

    @legend = @properties[:legend] || {}

    @size = [@base_map.size, @base_map.first.size]
    @tokens = @size[0].times.map do
      @size[1].times.map { nil }
    end

    @meta_map.each_with_index do |meta_row, column_index|
      meta_row.each_with_index do |token, row_index|
        token_type = @legend.dig(token.to_sym, :type)
        case (token_type)
        when "spawn_point"
          @spawn_points[@legend.dig(token.to_sym, :name)] = {
            location: [column_index, row_index],
          }
        end
      end
    end
  end

  def size
    @size
  end

  def place(pos_x, pos_y, entity, token = nil)
    raise "entity param is required" if entity.nil?

    @tokens[pos_x][pos_y] = { entity: entity, token: token || entity.name.first }
    @entities[entity] = [pos_x, pos_y]
  end

  def place_at_spawn_point(position, entity, token = nil)
    raise "unknown spawn position #{position}. should be any of #{@spawn_points.keys.join(",")}" if !@spawn_points.key?(position.to_s)

    pos_x, pos_y = @spawn_points[position.to_s][:location]
    place(pos_x, pos_y, entity, token)
  end

  def distance(entity1, entity2)
    pos1_x, pos1_y = @entities[entity1]
    pos2_x, pos2_y = @entities[entity2]

    Math.sqrt((pos1_x - pos2_x) ** 2 + (pos1_y - pos2_y) ** 2).ceil
  end

  def line_of_sight?(pos1_x, pos1_y, pos2_x, pos2_y, distance = nil)
    if (pos2_x == pos1_x)
      scanner = pos2_y > pos1_y ? (pos1_y...pos2_y) : (pos2_y...pos1_y)

      scanner.each_with_index do |y, index|
        return false if !distance.nil? && index > distance
        return false if (@base_map[pos1_x][y] == "#")
      end
      return true
    else
      m = (pos2_y - pos1_y).to_f / (pos2_x - pos1_x).to_f
      if (m == 0)
        scanner = pos2_x > pos1_x ? (pos1_x...pos2_x) : (pos2_x...pos1_x)
        scanner.each_with_index do |x, index|
          return false if !distance.nil? && index > distance
          return false if (@base_map[x][pos2_y] == "#")
        end
        return true
      else
        scanner = pos2_x > pos1_x ? (pos1_x...pos2_x) : (pos2_x...pos1_x)
        b = pos1_y - m * pos1_x
        step = 1 / m.abs
        scanner.step(step).each_with_index do |x, index|
          return false if !distance.nil? && index > distance
          y = (m * x + b).floor
          return false if (@base_map[x][y] == "#")
        end
        return true
      end
    end
  end

  def render
    @base_map.transpose.each_with_index.map do |row, row_index|
      row.each_with_index.map do |c, col_index|
        c = "·" if c == "."
        # render map layer
        token = @tokens[row_index][col_index] ? @tokens[row_index][col_index][:token] : nil
        token || c
      end.join
    end.join("\n") + "\n"
  end
end
