#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'highline/import'
require 'slack-ruby-client'

def configs
  @configs ||= JSON.parse File.read(CONFIG)
end

CONFIG = File.dirname(__FILE__) + '/config.json'

Slack.configure do |config|
  config.token = configs['SLACK_API_TOKEN']
end

client = Slack::Web::Client.new

if HighLine.agree("Send message as @lunchbot now? (type \"y\")")
  client.chat_postMessage(channel: '#alex-test-sf-lr',
                          text: "RANDOM MESSAGE",
                          as_user: true)
end
