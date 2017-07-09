# lunch-roulette
*Spin the wheel and have lunch with a stranger!*

The Lunch Roulette tool reads a list of email addresses from a Google
Sheet you specify (which most likely you'd populate using a Google
Form), and shuffles the respondents into groups of a size you specify.
Subsequently, it'll ping the groups inside grouped private messages
(MPIM) on Slack.

## Installing prerequisites

Clone the repo, and install the dependencies.

```sh
git clone git@github.com:toothbrush/lunch-roulette.git
cd lunch-roulette
gem install bundler # unless you already have Bundler available
bundle install
```

## Setting up

You'll need a few things set up before the Lunch Roulette script will
work.

1. The ID of the Google sheet where the list of emails is stored (grab
   it by copying the ID from the URL when you open the Google doc,
   it'll have the format
   `1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms`).
   
1. The URL of the place where users can sign up.  This is actually
   plain text that gets included in announcements, so feel free to add
   a descriptive text, e.g., "(Melbourne office)
   https://whatever.signup/".
   
1. Slack API token.  You'll need to have a Slack bot account set up:
   go to https://yourteam.slack.com/apps/manage/custom-integrations
   and click on "Bots".  Create a new one if necessary, or click on an
   existing one and copy its API token.
   
Fill these details in to `config.json`, which you can create by
copying the `config.json.template` file.

## Doing the thing

When everything is set up, you simply run the Lunch Roulette script.
Don't worry, it'll prompt you interactively before actually sending
any messages.

```sh
./lunchroulette.rb [--melbourne|--sf]
```

Have fun!
