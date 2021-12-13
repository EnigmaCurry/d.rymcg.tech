# Maubot

[Maubot](https://github.com/maubot/maubot#readme) is a plugin-based Matrix bot
written in Python.

Copy `.env-dist` to `.env`, and edit variables accordingly.

Copy `config.dist.yaml` to `config.yaml` and edit all the `example.com` domain
names to be your own domain name. Add your own username and password to the
`admins` section:

```
# List of administrator users. Plaintext passwords will be bcrypted on startup. Set empty password
# to prevent normal login. Root is a special user that can't have a password and will always exist.
admins:
    root: ""
    user1: "my dumb password"
```

Under the `registration_secrets` section put your matrix Home server domain
name. You do not need to fill in the secret.

Start Maubot with `docker-compose up -d`. Go to https://${DOMAIN}/_matrix/maubot
and login. Create your instance and client, and add plugins.

In order to create a client, you will need an existing Matrix ID and username
for the bot. Login as a normal user would using Element. Go to `Settings` ->
`Help/About`, scroll to the very bottom and find `Access Token`. Copy the access
token, and paste into the Maubot access token field on the client page.

Find and download plugins from https://github.com/maubot, then upload them
through the maubot plugin page. Create an instance linking the plugin to the
client. Invite the bot user to a room and you should be all set.
