#!/usr/bin/env ruby
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

def program_name
  "#{File.basename(__FILE__)} #{git_hash}"
end

def to_slack_handle(email)
  /(^[^@]+)@/.match(email)[1]
end

def git_hash
  `git describe --tags --long`.strip
end

# we want at least GROUP_SIZE people in a group.  One more is okay,
# too.
GROUP_SIZE = 4

# in case something goes wrong i want to be able to reproduce the same
# ordering again.  default to using today's date.
RANDOM_SEED = Time.now.strftime('%Y%m%d').to_i.freeze

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
SHEETKEY = is_sf ? configs['sf_sheet_key'] : configs['sheet_key']
SIGNUP = is_sf ? configs['sf_signup_link'] : configs['signup_link']
OFFICE_CHANNEL = is_sf ? "#sf-office" : "#melbourne"

# Worksheet of form responses:
ws = session.spreadsheet_by_key(SHEETKEY).worksheets.first

# Responses start on row 2, 1st is header
rows = ws.rows.drop(1)

participants = []

rows.each do |row|
  participants << { name: row[2], email: row[1] }
end

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

n = 1
groups.each do |grp|
  puts "\nGroup #{n} is:".white
  grp.each do |elt|
    puts " - #{elt[:name]}, @#{to_slack_handle(elt[:email])}"
  end
  n += 1
end

n = 1
groups.each do |grp|
  puts "Group #{n} has size #{grp.length}".blue
  if grp.length < GROUP_SIZE
    puts "WARNING: Hmmm!  Group #{grp} is #{grp.length} big...".red
  end
  n += 1
end

puts ''

Slack.configure do |config|
  config.token = configs['SLACK_API_TOKEN']
end

client = Slack::Web::Client.new

users_list = client.users_list['members']

mapping = Hash.new do |hash, key|
  raise("Slack user #{key} doesn't exist!")
end

users_list.each do |u|
  mapping[u['name']] = u['id']
end

exit unless HighLine.agree('Do these look right? (type "y")')

groups.each do |group|

  names = group.map { |x| "@#{to_slack_handle(x[:email])}" }.join(', ')
  rcpt = group.map { |x| mapping[to_slack_handle(x[:email])] }.join(',')

  puts "We'll send to this group: ".red
  puts names.cyan

  if HighLine.agree('Do you want to send MPIMs via Slack now? (type "y")')
    group_chat = client.mpim_open(users: rcpt)["group"]
    client.chat_postMessage(channel: group_chat["id"],
                            text: "Congratulations, you #{group.length} are together for this week's Lunch Roulette! Feel free to continue the discussion here, I'm just a shy bot and I'll keep quiet now. Experience shows that this works best if someone quickly takes initiative and kicks off the planning!",
                            as_user: true)
    client.chat_postMessage(channel: group_chat["id"],
                            text: "_Psst: I hope you like the new Slack integration. It's very hip and modern and 2.0 -- @paul.david is in the corner grumbling about the kids these days not using email..._",
                            as_user: true)

    client.chat_postMessage(channel: "@paul.david",
      text: "DEBUG INFO: group = #{names}",
      as_user: true)
  end
end

if HighLine.agree("Do you want to send reminder to #{OFFICE_CHANNEL} now? (type \"y\")")
  client.chat_postMessage(channel: OFFICE_CHANNEL,
    text: "This week's lunch roulette has just been kicked off, and it's already rumoured to be a roaring success. Don't miss out, sign up for next time: #{SIGNUP} :sun_with_face: Stay happy and healthy!",
    as_user: true)
end


