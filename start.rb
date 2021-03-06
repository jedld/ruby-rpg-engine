require 'rubygems'
require 'bundler/setup'
require 'tty-prompt'
require 'json'
require 'pry-byebug'
require 'active_support'
require 'active_support/core_ext'

$LOAD_PATH << File.dirname(__FILE__)

require 'lib/session'
require 'lib/cli/commandline_ui'

@prompt = TTY::Prompt.new
@session = Session.new

# event handlers
EventManager.standard_cli

# Starts a battle
# @param chosen_characters [Array]
# @param chosen_enemies [Array]
def start_battle(chosen_characters, chosen_enemies)
  map = BattleMap.new(@session, 'maps/battle_sim')
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
  puts 'Combat Order:'

  battle.combat_order.each_with_index do |entity, index|
    puts "#{index + 1}. #{entity.name}"
  end

  battle.while_active do |entity|
    command_line = CommandlineUI.new(battle, map, entity)

    puts ''
    puts "#{entity.name}'s turn"
    puts '==============================='
    if entity.npc?
      cycles = 0
      loop do
        cycles += 1
        action = controller.move_for(entity, battle)

        if action.nil?
          puts "#{entity.name}: End turn."
          break
        end

        battle.action!(action)
        battle.commit(action)
        break if action.nil?
      end
      puts map.render(line_of_sight: chosen_characters)
      @prompt.keypress('Press space or enter to continue', keys: %i[space return])
    else
      loop do
        puts map.render(line_of_sight: entity)
        puts "#{entity.hp}/#{entity.max_hp} actions: #{entity.total_actions(battle)} bonus action: #{entity.total_bonus_actions(battle)}, movement: #{entity.available_movement(battle)}"

        action = @prompt.select("#{entity.name} will") do |menu|
          entity.available_actions(@session, battle).each do |action|
            menu.choice action.label, action
          end
          menu.choice 'End', :end
          menu.choice 'Stop Battle', :stop
        end

        break if action == :end
        return if action == :stop

        action = command_line.action_ui(action, entity)
        next if action.nil?

        battle.action!(action)
        battle.commit(action)
        break unless true
      end
    end
  end

  puts '------------'
  puts "battle ended in #{battle.round + 1} rounds."
end

def training_dummy
  chosen_characters = @prompt.multi_select('Select Character') do |menu|
    @session.load_characters.each do |character|
      menu.choice character.name, character
    end
  end

  chosen_enemies = @prompt.multi_select('Select NPC') do |menu|
    @session.load_npcs.each do |character|
      menu.choice "#{character.name} (#{character.kind})", character
    end
  end

  start_battle(chosen_characters, chosen_enemies)
end

def dice_roller
  dice_roll_str = nil
  loop do
    dice_roll_str = @prompt.ask('Dice Roll (ex. d20, d8+1) (a) > ')
    dieRoll = DieRoll.roll dice_roll_str
    puts "#{dieRoll} = #{dieRoll.result}"
    break unless dice_roll_str != 'q'
  end
end

def start
  loop do
    answer = @prompt.select('Welcome to Wizards and Goblins (DnD 5e Adventure Engine)') do |menu|
      # menu.choice 'New Adventure ...', 1
      menu.choice 'Dice Roller', 1
      menu.choice 'Battle Simulator', 2
      menu.choice 'Exit', 3
    end
    exit(1) if answer == 3
    dice_roller if answer == 1
    training_dummy if answer == 2
    break unless true
  end
end

start
