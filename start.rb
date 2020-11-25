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

def start_battle(chosen_character, chosen_enemies)
  puts "Battle has started between #{chosen_character.name.colorize(:blue)} and #{chosen_enemies.map(&:name).join(",")}"
  map = BattleMap.new(@session, "maps/battle_sim")
  battle = Battle.new(@session, map)
  battle.add(chosen_character, :a, position: "spawn_point_1")

  chosen_enemies.each_with_index do |item, index|
    battle.add(item, :b, position: "spawn_point_#{index + 2}")
  end

  battle.start
  puts "Combat Order:"

  battle.combat_order.each_with_index do |entity, index|
    puts "#{index + 1}. #{entity.name}"
  end

  battle.while_active do |entity|
    puts map.render
    puts ""
    puts "#{entity.name}'s turn"
    puts "==============================="
    if entity.npc?
      controller = AiController::Standard.new
      action = controller.move_for(entity, battle)
      battle.action!(action)
      battle.commit(action)
    else
      puts "#{entity.hp}/#{entity.max_hp} actions: #{entity.total_actions(battle)} bonus action: #{entity.total_bonus_actions(battle)}, movement: #{entity.available_movement(battle)}"
      action = @prompt.select("#{entity.name} will") do |menu|
        entity.available_actions(@session).each do |action|
          menu.choice action.label, action
        end
      end

      case action.action_type
      when :attack
        target = @prompt.select("#{entity.name} targets") do |menu|
          battle.valid_targets_for(entity, action).each do |target|
            menu.choice target.name, target
          end
        end

        action.target = target
        battle.action!(action)
        battle.commit(action)
      end
    end
  end
  puts "------------"
  puts "battle ended in #{battle.round + 1} rounds."
end

def training_dummy
  chosen_character = @prompt.select("Select Character") do |menu|
    @session.load_characters.each do |character|
      menu.choice character.name, character
    end
  end

  chosen_enemies = @prompt.multi_select("Select NPC") do |menu|
    @session.load_npcs.each do |character|
      menu.choice "#{character.name} (#{character.kind})", character
    end
  end

  start_battle(chosen_character, chosen_enemies)
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
