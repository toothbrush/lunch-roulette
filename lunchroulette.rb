#!/usr/bin/env ruby
require 'date'
require 'google_drive'
require 'colorize'
require 'pp'
require 'mail'
require 'json'
require 'highline/import'

def program_name
  "#{File.basename(__FILE__)} #{git_hash}"
end

def git_hash
  `git describe --tags --long`.strip
end

def first_name(input)
  input.strip.split[0]
end

def send_mail(mail_to, mail_body, configs)
  options = { :address    => 'smtp.gmail.com',
    :port                 => 587,
    :domain               => 'redbubble.com',
    :user_name            => configs["user_name"],
    :password             => configs["password"],
    :authentication       => 'plain',
    :enable_starttls_auto => true }

  Mail.defaults do
    delivery_method :smtp, options
  end

  from_address = Mail::Address.new configs['user_name']
  from_address.display_name = "Roulette Monkey"

  list = "lunch-roulette"

  mail = Mail.new do
    from     from_address.format # returns "John Doe <john@example.com>"
    to       mail_to
    bcc      configs["user_name"] # send debug/admin output to Paul
    subject  "[#{list}] Group assignments!"
    body     mail_body
  end
  mail.header['User-agent'] = program_name
  mail.header['List-ID']    = list

  mail.deliver!
  puts "Sent mail to:".yellow
  puts "   " + mail_to.green
end

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

# The lunch roulette sheet:
SHEETKEY = configs["sheet_key"]
SIGNUP = configs["signup_link"]

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

n = 1
groups.each do |grp|
  puts "Group #{n} has size #{grp.length}".blue
  if grp.length < GROUP_SIZE
    puts "WARNING: Hmmm!  Group #{grp} is #{grp.length} big...".red
  end
  n+=1
end

puts ""
exit unless HighLine.agree('Do you want to send the group assignment emails? (type "y")')

groups.each do |group|

  body = "Hello gamblers :),

This is your Lunch Roulette team assignment mailing!  Forgive me if
there are errors or ugliness, as i am but a dumb script hacked
together by Paul one night.

Your buddies:

#{group.map { |x| "- " + first_name(x[:name]) }.join("\n")}

You'll probably want to contact them and set up a lunch date sometime
soon!  The aim is to spin the Roulette wheel roughly fortnightly, so
you'll want to plan your lunch sometime within the next two weeks,
probably.  Experience shows that using a tool like
https://www.doodle.com to schedule the event is easier for everyone.
Have fun :)

Hint -> hitting reply-to-all should do the trick fine, and put you in
contact with only your lunchmates!

Cheers,
The Lunch Roulette Monkey (on behalf of Paul)

PS: Tell everyone who hasn't yet played Lunch Roulette to join up for
next time here! #{SIGNUP} :)

--
Automated Lunch Roulette mailing
FYI the random seed was #{RANDOM_SEED}.
Questions?  Tired of participating?  Talk to #{configs["user_name"]}.
"

  rcpt = group.map { |x| x[:email] }.join(", ")

  send_mail(rcpt, body, configs)
end

# Finally, send me an email with all the data:
send_mail(configs["user_name"], "Here are all the group assignments!

#{groups.pretty_inspect}

...and all their emails:

#{participants.map { |x| x[:email] }.sort.join(", ")}

EOF", configs)
