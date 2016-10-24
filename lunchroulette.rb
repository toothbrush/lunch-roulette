#!/usr/bin/env ruby
require 'date'
require 'google_drive'
require 'colorize'
require 'pp'

def first_name(input)
  input.strip.split[0]
end

# The lunch roulette sheet:
SHEETKEY = "1LoyFeyK53P6pJ8Xcr3Q9_P82jvKW6bgYk3-RMkmn_6o".freeze

# for now there's no smart logic to finding a group size.  40 divides
# evenly by 5.
GROUP_SIZE = 5.freeze

# in case something goes wrong i want to be able to reproduce the same
# ordering again.  default to using today's date.
RANDOM_SEED = Time.now.strftime("%d%m%Y").to_i.freeze

GOOGLECONFIG = File.dirname(__FILE__) + "/googleconfig.json"
CONFIG = File.dirname(__FILE__) + "/config.json"

# Creates a session. This will prompt the credential via command line
# for the first time and save it to config.json file for later use.
session = GoogleDrive::Session.from_config(GOOGLECONFIG)
configs = JSON.parse File.read(CONFIG)

# Worksheet of form responses:
ws = session.spreadsheet_by_key(SHEETKEY).worksheets[1]

# Responses start on row 2, 1st is header
rows = ws.rows.drop(1)

participants = []

rows.each do |row|
  participants << { name: row[1] , email: row[2] }
end

puts "Found #{participants.length} participants.".light_blue

# Randomise all the people!!
r = Random.new(RANDOM_SEED)
puts "Using random seed #{RANDOM_SEED}."
participants = participants.shuffle(random: r)

groups = participants.each_slice(GROUP_SIZE).to_a

n = 1
groups.each do |grp|
  puts "\nGroup #{n} is:".white
  grp.each do |elt|
    puts " - #{first_name elt[:name]}, #{elt[:email]}"
  end
  n+=1
end

puts "\nAll email addresses (for convenient copying):\n".blue
puts participants.map { |x| x[:email] }.join(", ")