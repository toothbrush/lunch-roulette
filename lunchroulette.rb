#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# frozen_string_literal: true

require 'date'
require 'google_drive'
require 'colorize'
require 'pp'
require 'json'
require 'highline/import'
require 'slack-ruby-client'

def configs
  @configs ||= JSON.parse File.read(CONFIG)
end

def max(a, b)
  a > b ? a : b
end

def to_slack_handle(email)
  /(^[^@]+)@/.match(email)[1]
end

# we want at least GROUP_SIZE people in a group.  One more is okay,
# too.
GROUP_SIZE = 6

# in case something goes wrong i want to be able to reproduce the same
# ordering again.  default to using today's date.
RANDOM_SEED = (ENV['RANDOM_SEED'] || Time.now.strftime('%Y%m%d')).to_i.freeze

GOOGLECONFIG = File.dirname(__FILE__) + '/googleconfig.json'
CONFIG = File.dirname(__FILE__) + '/config.json'

args = Hash[ARGV.flat_map { |s| s.scan(/--?([^=\s]+)(?:=(\S+))?/) }]

is_sf = args.key? 'sf'
is_mel = args.key? 'melbourne'

unless is_sf || is_mel
  puts 'Please specify a city with --sf or --melbourne!'
  exit
end

# Creates a session. This will prompt the credential via command line
# for the first time and save it to config.json file for later use.
session = GoogleDrive::Session.from_config(GOOGLECONFIG)

# The lunch roulette sheet:
SHEETKEY = configs['opt_out_sheet']
SIGNUP = configs['opt_out_link']
OFFICE_CHANNEL = is_sf ? '#sf-office' : '#melbourne'

Slack.configure do |config|
  config.token = configs['SLACK_API_TOKEN']
end

client = Slack::Web::Client.new

puts "Getting inhabitants of #{OFFICE_CHANNEL}..."
office_channel_info = client.channels_info(channel: OFFICE_CHANNEL)

raw_participants = office_channel_info['channel']['members']

puts "Getting all users..."
users_list = client.users_list['members']

mapping = {}

users_list.each do |u|
  next if u['deleted']     # skip over deleted users
  next if u['is_bot']      # skip over bots
  next if u['is_app_user']
  mapping[u['id']] = { name: u['name'],
                       timezone: u['tz'],
                       deleted: u['deleted'] }
end

participants = []
puts "Translating UIDs to Slack usernames..."
# Assuming here we get no dups / invalid UIDs, etc.
raw_participants.each do |p|
  next unless mapping[p]
  username = mapping[p][:name]
  if mapping[p][:timezone] =~ /^Australia\/.+/
    participants << { username: username, id: p }
  else
    puts "#{username.light_red} is in \"#{mapping[p][:timezone]}\", excluding."
  end
end

exclusions = []

puts "Getting opt-out users..."
# Worksheet of form responses:
ws = session.spreadsheet_by_key(SHEETKEY).worksheets.first

# Responses start on row 2, 1st is header
rows = ws.rows.drop(1)

rows.each do |row|
  exclusions << row[2] # this is Slack username without the @
  puts "[OPTOUT] #{row[2]}".red
end

puts "Number of                     exclusions: #{exclusions.length}"
before = participants.length
puts "Number of participants before exclusions: #{before}"
participants = participants.reject do |elem|
  exclusions.include? elem[:username]
end
after = participants.length
puts "Number of participants after  exclusions: #{after}"
print "Sanity check: "

exit unless exclusions.length + after == before
puts "passed."

puts "Found #{participants.length} participants.".magenta

NGROUPS = max(1, participants.length / GROUP_SIZE) # automatically rounds down

puts "Creating #{NGROUPS} groups, with #{GROUP_SIZE}"\
  " or #{GROUP_SIZE + 1} participants each.".magenta

# Randomise All the People!!
r = Random.new(RANDOM_SEED)
puts "Using random seed #{RANDOM_SEED}.".yellow
participants = participants.shuffle(random: r)

groups = Array.new(NGROUPS) { [] }

currentgroup = 0
participants.each do |participant|
  groups[currentgroup] << participant
  currentgroup = (currentgroup + 1) % NGROUPS
end

nr_picked_groups = (NGROUPS / 5.to_f).ceil

puts "Allow 20% of people to get picked, that's #{nr_picked_groups} groups."
groups = groups.first nr_picked_groups

n = 1
groups.each do |grp|
  puts "\nGroup #{n} is:".white
  grp.each do |elt|
    puts " - #{elt[:username]} (#{elt[:id]})"
  end
  n += 1
end

puts ''

exit unless HighLine.agree('Do these look right? (type "y")')

groups.each do |group|
  names = group.map { |x| "@#{x[:username]}" }.join(', ')
  rcpt = group.map { |x| x[:id] }.join(',')

  puts "We'll send to this group: ".red
  puts names.cyan

  next unless HighLine.agree('Send MPIMs via Slack now? (type "y")')
  group_chat = client.mpim_open(users: rcpt)['group']
  client.chat_postMessage(
    channel: group_chat['id'],
    link_names: 1,
    text: "Congratulations, you've been selected for this Lunch Roulette! " \
      "We're trialling a new approach where everyone in #{OFFICE_CHANNEL} is " \
      "automatically entered into the lottery – " \
      "if you don't want to join in, feel free to ignore. " \
      "Have a nice day! :smile:",
    as_user: true
  )
  client.chat_postMessage(
    channel: group_chat['id'],
    link_names: 1,
    text: "_Psst: Don't understand what Lunch Roulette is? Want to opt-out? " \
      "More information here: " \
      "https://github.com/toothbrush/lunch-roulette/wiki. " \
      "Please feel free to send comments/flames/thoughts to @paul.david._",
    as_user: true
  )

  client.chat_postMessage(channel: '@paul.david',
                          text: "DEBUG INFO: group = #{names}",
                          as_user: true)
end

client.chat_postMessage(channel: '@paul.david',
                        text: "DEBUG INFO: seed = #{RANDOM_SEED}",
                        as_user: true)
