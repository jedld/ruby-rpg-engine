require 'rubygems'
require 'bundler/setup'

require "tty-prompt"

@prompt = TTY::Prompt.new

def start
  answer = @prompt.select("Welcome to Wizards and Goblins (DnD 5e Adventure Engine)") do |menu|
    menu.choice 'New Adventure ...', 1
    menu.choice 'Load Game', 2
    menu.choice 'Exit', 3
  end
  exit(1) if answer == 1
end


start