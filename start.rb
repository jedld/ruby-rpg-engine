require 'rubygems'
require 'bundler/setup'
require "tty-prompt"
require 'json'
require 'pry-byebug'
require 'active_support'
require 'active_support/core_ext'

$LOAD_PATH << File.dirname(__FILE__)

require "lib/player_character"
require "lib/npc"
require "lib/battlemap"
require "lib/session"


@prompt = TTY::Prompt.new
@session = Session.new

def start_battle(chosen_character, chosen_enemy)
  puts "Battle has started between #{chosen_character.name} and #{chosen_enemy.name}"

  battle_map = BattleMap.new
  battle_map.add(chosen_character)
  battle_map.add(chosen_enemy)
  battle_map.start

  @prompt.select("#{chosen_character.name} will") do |menu|

  end
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
      menu.choice 'New Adventure ...', 1
      menu.choice 'Load Game', 2
      menu.choice 'Training Dummy', 3
      menu.choice 'Exit', 4
    end
    exit(1) if answer == 4
    training_dummy if answer == 3
  end while true
end


start