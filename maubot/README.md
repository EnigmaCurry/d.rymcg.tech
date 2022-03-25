# Maubot

[Maubot](https://github.com/maubot/maubot#readme) is a plugin-based Matrix bot
written in Python.

Run `make config`

Run `make install`

Run `make open` to open the webpage, and then login with the username `admin`
and the same password as set in your env file called `MAUBOT_ADMIN_PASSWORD`.

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
  * Run `make login` and enter the login details.

Example with `make login`:

```
$ make login
Login with the maubot client:
Use the same Admin username/password set in your .env file.
Use the Server http://localhost:29316
Set the Alias as localhost

? Username admin
? Password **************************
? Server http://localhost:29316
? Alias localhost
Logged in successfully

Now login to the matrix account for maubots use:

? Homeserver matrix.example.com
? Username maubot
? Password **************************
Successfully created client for @maubot:example.com / maubot_99QEF6C7.
```

  * Find and download plugins from
    [https://github.com/maubot](https://github.com/maubot) then upload them
    through the maubot plugin page.
  * Create a plugin instance linking the plugin to the client. 
  * Invite the bot user to a room and you should be all set.
