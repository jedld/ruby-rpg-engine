require 'rubygems'
require 'bundler/setup'
require "tty-prompt"
require 'json'
require 'pry-byebug'
require 'active_support'
require 'active_support/core_ext'

$LOAD_PATH << File.dirname(__FILE__)

require "lib/session"

@prompt = TTY::Prompt.new
@session = Session.new

# event handlers
EventManager.register_event_listener([:died], ->(event) {puts "#{event[:source].name} died." })
EventManager.register_event_listener([:unconsious], ->(event) { puts "#{event[:source].name} unconsious." })
EventManager.register_event_listener([:attacked], ->(event) { puts "#{event[:source].name} attacked #{event[:target].name} to Hit: #{event[:attack_roll].to_s} for #{event[:value]} #{event[:damage_type]} damage." })
EventManager.register_event_listener([:miss], ->(event) { puts "rolled #{event[:attack_roll].to_s} ... #{event[:source].name} missed his attack on #{event[:target].name}" })
EventManager.register_event_listener([:initiative], ->(event) { puts "#{event[:source].name} rolled a #{event[:roll].to_s} = (#{event[:value]}) with dex tie break for initiative." })


def start_battle(chosen_character, chosen_enemy)
  puts "Battle has started between #{chosen_character.name} and #{chosen_enemy.name}"

  battle_map = Battle.new(@session)
  battle_map.add(chosen_character, :a)
  battle_map.add(chosen_enemy, :b)
  battle_map.start
  puts "Combat Order:"

  battle_map.combat_order.each_with_index do |entity, index|
    puts "#{index + 1}. #{entity.name}"
  end

  battle_map.while_active do |entity|
    if entity.npc?
      puts "#{entity.name} just stands there."
    else
      puts "#{entity.name}'s turn"
      action = @prompt.select("#{entity.name} will") do |menu|
        entity.available_actions(@session).each do |action|
          menu.choice action.label, action
        end
      end
      if action.action_type == :attack
        target = @prompt.select("#{entity.name} will attack") do |menu|
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

  chosen_enemy = @prompt.select("Select NPC") do |menu|
    @session.load_npcs.each do |character|
      menu.choice "#{character.name} (#{character.kind})", character
    end
  end

  start_battle(chosen_character, chosen_enemy)
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