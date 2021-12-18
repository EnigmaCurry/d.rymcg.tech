# Maubot

[Maubot](https://github.com/maubot/maubot#readme) is a plugin-based Matrix bot
written in Python.

Copy `.env-dist` to `.env`, and edit variables accordingly.

Start Maubot with `docker-compose up -d`. Go to https://${DOMAIN}/_matrix/maubot
and login. 

You must provision a Matrix ID and password on your homeserver.

You need to find the Access Token and Device ID for your login. The easiest way
to retrieve this is by logging into the new maubot user with Element (in a
private browser window). In Element, go to `Settings` -> `Help/About`, scroll to
the very bottom and find `Access Token`. Copy the access token, and paste into
the Maubot access token field on the client page. In Element, go to `Security &
Privacy`, find the `Cryptography` section, and find the `Session ID`, the
session ID is the same as the device ID, copy this as well to the Maubot client
page, and save it.

Find and download plugins from https://github.com/maubot, then upload them
through the maubot plugin page. Create an instance linking the plugin to the
client. Invite the bot user to a room and you should be all set.
