require 'rubygems'
require 'bundler/setup'
require "tty-prompt"
require 'json'
require 'pry-byebug'
require 'active_support'
require 'active_support/core_ext'

$LOAD_PATH << File.dirname(__FILE__)

require "lib/player_character"

@prompt = TTY::Prompt.new

def load_characters
  files = Dir[File.join(File.dirname(__FILE__), "characters", "*.json") ]
  files.map do |file|
    char_content = JSON.parse(File.read(file))
    PlayerCharacter.new(char_content)
  end
end

def training_dummy
  answer = @prompt.select("Select Character") do |menu|
    load_characters.each do |character|
      menu.choice character.name
    end
    menu.choice 'Back', 4
  end
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