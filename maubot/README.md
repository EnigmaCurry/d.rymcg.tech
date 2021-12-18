# Maubot

[Maubot](https://github.com/maubot/maubot#readme) is a plugin-based Matrix bot
written in Python.

Copy `.env-dist` to `.env`, and edit variables accordingly.

Start Maubot with `docker-compose up -d`. Go to https://${DOMAIN}/_matrix/maubot
and login. 

The config file is generated on the first startup, from a template that uses
your environment variables. Since this happens only once, if you need to change
the configuration later, you will need to delete `/data/config.yaml` from the
volume, or just delete the entire volume.

You must provision a *brand new* Matrix ID and password on your homeserver. It
is important that the account has never been logged into before, in order for
the encryption keys to be setup on the first login via `mbc auth` (Actually, I
couldn't get encryption to work at all, the bot does not respond in encrypted
rooms, but he's supposed to :/ ):

Setup:
  * Login to maubot: `docker-compose exec maubot mbc login`
  * Login to homeserver: `docker-compose exec maubot mbc auth --update-client`
  * Find and download plugins from https://github.com/maubot, then upload them
    through the maubot plugin page. 
  * Create a plugin instance linking the plugin to the client. 
  * Invite the bot user to a room and you should be all set.
