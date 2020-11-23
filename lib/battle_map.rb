class BattleMap
  def initialize(session, map_file)
    @session = session
    @map_file = map_file

    @properties = YAML.load_file(File.join(File.dirname(__FILE__), "..", "maps", "#{map_file}.yml")).deep_symbolize_keys!

    @base_map = @properties.dig(:map, :base).map do |lines|
      lines.each_char.map.to_a
    end

    @size = [@base_map.size, @base_map.first.size]
    @tokens = @size[0].times.map do
      @size[1].times.map { nil }
    end
  end

  def size
    @size
  end

  def place(pos_x, pos_y, entity, token = nil)
    @tokens[pos_x][pos_y] = { entity: entity, token: token || entity.name.first }
  end

  def render
    @base_map.each_with_index.map do |row, row_index|
      row.each_with_index.map do |c, col_index|
        # render map layer
        token = @tokens[row_index][col_index] ? @tokens[row_index][col_index][:token] : nil
        token || c
      end.join
    end.join("\n") + "\n"
  end
end
