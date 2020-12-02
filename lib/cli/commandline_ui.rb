class CommandlineUI
  attr_reader :battle, :map, :entity

  def initialize(battle, map, entity)
    @battle = battle
    @map = map
    @entity = entity
    @prompt = TTY::Prompt.new
  end

  def attack_ui(entity, action)
    target = @prompt.select("#{entity.name} targets") do |menu|
      battle.valid_targets_for(entity, action).each do |target|
        menu.choice target.name, target
      end
      menu.choice "Manual"
      menu.choice "Back", nil
    end

    return nil if target == "Back"

    if target == "Manual"
      target = target_ui(validation: -> (selected) {
        selected_entity = map.entity_at(*selected)

        return false unless selected_entity

        battle.valid_targets_for(entity, action).include?(selected_entity)
      })
      target = target&.first

      return nil if target.nil?
    end

    target
  end

  def target_ui(initial_pos: nil, num_select: 1, validation: nil)
    selected = []
    initial_pos = initial_pos || map.position_of(entity)
    begin
      puts "\e[H\e[2J"
      puts " "
      puts map.render(line_of_sight: entity, select_pos: initial_pos)
      @prompt.say("#{map.entity_at(*initial_pos)&.name}")
      movement = @prompt.keypress(" (wsad) - movement, x - select, r - reset")

      if movement == "w"
        new_pos = [initial_pos[0], initial_pos[1] - 1]
      elsif movement == "a"
        new_pos = [initial_pos[0] - 1, initial_pos[1]]
      elsif movement == "d"
        new_pos = [initial_pos[0] + 1, initial_pos[1]]
      elsif movement == "s"
        new_pos = [initial_pos[0], initial_pos[1] + 1]
      elsif movement == "x"
        next if validation && !validation.call(new_pos)

        selected << initial_pos
      elsif movement == "r"
        new_pos = map.position_of(entity)
        next
      else
        next
      end

      next if new_pos.nil?
      next if !map.line_of_sight_for?(entity, *new_pos)


      initial_pos = new_pos
    end while movement != "x"

    selected.map { |e| map.entity_at(*e)}
  end

  def move_ui(as_dash: false)
    path = [map.position_of(entity)]
    begin
      puts "\e[H\e[2J"
      puts "movement #{map.movement_cost(entity, path).to_s.colorize(:green)}ft."
      puts " "
      puts map.render(line_of_sight: entity, path: path)
      movement = @prompt.keypress(" (wsad) - movement, x - confirm path, r - reset")

      if movement == "w"
        new_path = [path.last[0], path.last[1] - 1]
      elsif movement == "a"
        new_path = [path.last[0] - 1, path.last[1]]
      elsif movement == "d"
        new_path = [path.last[0] + 1, path.last[1]]
      elsif movement == "s"
        new_path = [path.last[0], path.last[1] + 1]
      elsif movement == "x"
        next if !map.placeable?(entity, *path.last, battle)
        return path
      elsif movement == "q"
        new_path = [path.last[0]-1, path.last[1] - 1]
      elsif movement == 'e'
        new_path = [path.last[0]+1, path.last[1] - 1]
      elsif movement == 'z'
        new_path = [path.last[0]-1, path.last[1] + 1]
      elsif movement == 'c'
        new_path = [path.last[0]+1, path.last[1] + 1]
      elsif movement == "r"
        path = [map.position_of(entity)]
        next
      else
        next
      end

      if path.size > 1 && new_path == path[path.size - 2]
        path.pop
      elsif map.valid_position?(*new_path) && map.movement_cost(entity, path + [new_path]) <= (as_dash ? entity.speed : entity.available_movement(battle))
        path << new_path
      end
    end while movement != "x"
  end
end