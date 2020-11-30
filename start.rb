require "rubygems"
require "bundler/setup"
require "tty-prompt"
require "json"
require "pry-byebug"
require "active_support"
require "active_support/core_ext"

$LOAD_PATH << File.dirname(__FILE__)

require "lib/session"

@prompt = TTY::Prompt.new
@session = Session.new

# event handlers
EventManager.standard_cli

def move_ui(battle, map, entity, as_dash: false)
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

def start_battle(chosen_characters, chosen_enemies)
  map = BattleMap.new(@session, "maps/battle_sim")
  battle = Battle.new(@session, map)
  chosen_characters.each_with_index do |chosen_character, index|
    battle.add(chosen_character, :a, position: "spawn_point_#{index + 1}", token: chosen_character.name[0])
  end

  controller = AiController::Standard.new

  chosen_enemies.each_with_index do |item, index|
    controller.register_handlers_on(item)
    battle.add(item, :b, position: "spawn_point_#{index + 3}")
  end

  battle.start
  puts "Combat Order:"

  battle.combat_order.each_with_index do |entity, index|
    puts "#{index + 1}. #{entity.name}"
  end

  battle.while_active do |entity|
    puts ""
    puts "#{entity.name}'s turn"
    puts "==============================="
    if entity.npc?
      cycles = 0
      begin
        cycles += 1
        action = controller.move_for(entity, battle)

        if action.nil?
          puts "#{entity.name}: End turn."
          break
        end

        battle.action!(action)
        battle.commit(action)
      end while !action.nil?
      puts map.render(line_of_sight: chosen_characters.first)
      @prompt.keypress("Press space or enter to continue", keys: [:space, :return])
    else
      begin
        puts map.render(line_of_sight: entity)
        puts "#{entity.hp}/#{entity.max_hp} actions: #{entity.total_actions(battle)} bonus action: #{entity.total_bonus_actions(battle)}, movement: #{entity.available_movement(battle)}"

        action = @prompt.select("#{entity.name} will") do |menu|
          entity.available_actions(@session, battle).each do |action|
            menu.choice action.label, action
          end
          menu.choice "Stop Battle", :stop
        end

        case action.action_type
        when :attack
          target = @prompt.select("#{entity.name} targets") do |menu|
            battle.valid_targets_for(entity, action).each do |target|
              menu.choice target.name, target
            end
            menu.choice "Back", nil
          end

          next if target == "Back"

          action.target = target
          battle.action!(action)
          battle.commit(action)
        when :help
          target = @prompt.select("#{entity.name} targets") do |menu|
            battle.valid_targets_for(entity, action).each do |target|
              menu.choice target.name, target
            end
            menu.choice "Back", nil
          end

          next if target == "Back"

          action.target = target
          battle.action!(action)
          battle.commit(action)
        when :dodge, :disengage, :disengage_bonus
          battle.action!(action)
          battle.commit(action)
        when :move
          move_path = move_ui(battle, map, entity)
          next if move_path.nil?

          action.move_path = move_path
          battle.action!(action)
          battle.commit(action)
        when :dash, :dash_bonus
          move_path = move_ui(battle, map, entity, as_dash: true)
          next if move_path.nil?

          action.move_path = move_path
          action.as_dash = true
          battle.action!(action)
          battle.commit(action)
        end
      end while action.action_type != :end
    end
  end

  puts "------------"
  puts "battle ended in #{battle.round + 1} rounds."
end

def training_dummy
  chosen_characters = @prompt.multi_select("Select Character") do |menu|
    @session.load_characters.each do |character|
      menu.choice character.name, character
    end
  end

  chosen_enemies = @prompt.multi_select("Select NPC") do |menu|
    @session.load_npcs.each do |character|
      menu.choice "#{character.name} (#{character.kind})", character
    end
  end

  start_battle(chosen_characters, chosen_enemies)
end

def dice_roller
  dice_roll_str = nil
  begin
    dice_roll_str = @prompt.ask("Dice Roll (ex. d20, d8+1) (a) > ")
    dieRoll = DieRoll.roll dice_roll_str
    puts "#{dieRoll.to_s} = #{dieRoll.result}"
  end while dice_roll_str != "q"
end

def start
  begin
    answer = @prompt.select("Welcome to Wizards and Goblins (DnD 5e Adventure Engine)") do |menu|
      # menu.choice 'New Adventure ...', 1
      menu.choice "Dice Roller", 1
      menu.choice "Battle Simulator", 2
      menu.choice "Exit", 3
    end
    exit(1) if answer == 3
    dice_roller if answer == 1
    training_dummy if answer == 2
  end while true
end

start
