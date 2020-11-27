class BattleMap
  attr_reader :spawn_points, :size

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
    end.transpose if @properties.dig(:map, :meta)

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
    end if @meta_map
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
    puts "place #{entity.name} at #{pos_x}, #{pos_y}"
  end

  def distance(entity1, entity2)
    pos1_x, pos1_y = @entities[entity1]
    pos2_x, pos2_y = @entities[entity2]

    Math.sqrt((pos1_x - pos2_x) ** 2 + (pos1_y - pos2_y) ** 2).ceil
  end

  # Entity to look around
  def look(entity, distance = nil)
    @entities.map do |k, v|
      next if k == entity

      pos1_x, pos1_y = v
      next unless line_of_sight_for?(entity, pos1_x, pos1_y, distance)

      [k, [pos1_x, pos1_y]]
    end.compact.to_h
  end

  def line_of_sight_for?(entity, pos2_x, pos2_y, distance = nil)
    raise "cannot find entity" if @entities[entity].nil?

    pos1_x, pos1_y = @entities[entity]
    line_of_sight?(pos1_x, pos1_y, pos2_x, pos2_y, distance)
  end

  def position_of(entity)
    @entities[entity]
  end

  def move_to!(entity, pos_x, pos_y)
    cur_x, cur_y = @entities[entity]
    @tokens[pos_x][pos_y] = @tokens[cur_x][cur_y]
    @tokens[cur_x][cur_y] = nil
    @entities[entity] = [pos_x, pos_y]
  end

  def valid_position?(pos_x, pos_y)
    return false if pos_x >= @base_map.size || pos_x < 0 || pos_y >= @base_map[0].size || pos_y < 0 # check for out of bounds
    return false if @base_map[pos_x][pos_y] == "#"

    true
  end

  def movement_cost(path = [])
    return 0 if path.empty?

    (path.size - 1) * 5
  end

  def passable?(entity, pos_x, pos_y, battle = nil)
    return false if @base_map[pos_x][pos_y] == '#'
    if battle && @tokens[pos_x][pos_y]
      source_state = battle.entity_state_for(entity)
      source_group = source_state[:group]
      location_state = battle.entity_state_for(@tokens[pos_x][pos_y])
      location_group = location_state[:group]
      return true if location_group.nil?
      return true if location_group == source_group
      return false if location_group != source_group
    end

    return true
  end

  # check if this interrupts line of sight (not necessarily movement)
  def opaque?(pos_x, pos_y)
    case(@base_map[pos_x][pos_y])
    when "#"
      return true
    end

    false
  end

  def line_of_sight?(pos1_x, pos1_y, pos2_x, pos2_y, distance = nil)
    return true if [pos1_x, pos1_y] == [pos2_x, pos2_y]

    if (pos2_x == pos1_x)
      scanner = pos2_y > pos1_y ? (pos1_y...pos2_y) : (pos2_y...pos1_y)

      scanner.each_with_index do |y, index|
        return false if !distance.nil? && index > distance
        next if (y == pos1_y) || (y == pos2_y)
        return false if opaque?(pos1_x, y)
      end
      return true
    else
      m = (pos2_y - pos1_y).to_f / (pos2_x - pos1_x).to_f
      if (m == 0)
        scanner = pos2_x > pos1_x ? (pos1_x...pos2_x) : (pos2_x...pos1_x)
        scanner.each_with_index do |x, index|
          return false if !distance.nil? && index > distance
          next if (x == pos1_x) || (x == pos2_x)
          return false if (@base_map[x][pos2_y] == "#")
        end
        return true
      else
        scanner = pos2_x > pos1_x ? (pos1_x...pos2_x) : (pos2_x...pos1_x)
        b = pos1_y - m * pos1_x
        step = (m.abs > 1) ? 1 / m.abs : m.abs

        scanner.step(step).each_with_index do |x, index|
          y = (m * x + b).round

          return false if !distance.nil? && index > distance
          next if (x.round == pos1_x && y == pos1_y) || (x.round == pos2_x && y == pos2_y)
          return false if (@base_map[x.round][y] == "#")
        end
        return true
      end
    end
  end

  def render(line_of_sight: nil, path: [])
    @base_map.transpose.each_with_index.map do |row, row_index|
      row.each_with_index.map do |c, col_index|
        c = "·".colorize(:light_black) if c == "."
        c = "#".colorize(color: :black, background: :white) if c == "#"

        if !path.empty?
          next "X" if path[0] == [col_index, row_index]
          next "+" if path.include?([col_index, row_index])
          next " " if line_of_sight && !line_of_sight?(path.last[0], path.last[1], col_index, row_index)
        else
          next " " if line_of_sight && !line_of_sight_for?(line_of_sight, col_index, row_index)
        end

        # render map layer
        token = @tokens[col_index][row_index] ? @tokens[col_index][row_index][:token] : nil
        token || c
      end.join
    end.join("\n") + "\n"
  end
end
