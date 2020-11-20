require 'rubygems'
require 'bundler/setup'
require "tty-prompt"
require 'json'
require 'pry-byebug'
require 'active_support'
require 'active_support/core_ext'
require 'colorize'

$LOAD_PATH << File.dirname(__FILE__)

require "lib/session"

@prompt = TTY::Prompt.new
@session = Session.new

# event handlers
EventManager.standard_cli

def start_battle(chosen_character, chosen_enemies)
  puts "Battle has started between #{chosen_character.name.colorize(:blue)} and #{chosen_enemies.map(&:name).join(',')}"

  battle_map = Battle.new(@session)
  battle_map.add(chosen_character, :a)

  chosen_enemies.each do |item|
    battle_map.add(item, :b)
  end

  battle_map.start
  puts "Combat Order:"

  battle_map.combat_order.each_with_index do |entity, index|
    puts "#{index + 1}. #{entity.name}"
  end

  battle_map.while_active do |entity|
    puts "#{entity.name}'s turn"
    puts ""
    if entity.npc?
      controller = AiController::Standard.new
      action = controller.move_for(entity, battle_map)
      battle_map.action!(action)
      battle_map.commit(action)
    else
      puts "#{entity.hp}/#{entity.max_hp}"
      action = @prompt.select("#{entity.name} will") do |menu|
        entity.available_actions(@session).each do |action|
          menu.choice action.label, action
        end
      end

      case action.action_type
      when :attack
        target = @prompt.select("#{entity.name} targets") do |menu|
          battle_map.valid_targets_for(entity, action).each do |target|
            menu.choice target.name, target
          end
        end

        action.target = target
        battle_map.action!(action)
        battle_map.commit(action)
      end
    end
  end
  puts "------------"
  puts "battle ended in #{battle_map.round + 1} rounds."
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

def start
  begin
    answer = @prompt.select("Welcome to Wizards and Goblins (DnD 5e Adventure Engine)") do |menu|
      # menu.choice 'New Adventure ...', 1
      # menu.choice 'Load Game', 2
      menu.choice 'Battle Simulator', 3
      menu.choice 'Exit', 4
    end
    exit(1) if answer == 4
    training_dummy if answer == 3
  end while true
end


start