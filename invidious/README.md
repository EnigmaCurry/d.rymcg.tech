# Invidious

[Invidious](https://github.com/iv-org/invidious) is an alternative front-end to
YouTube.

This install assumes you want a private instance, protected by
username/password. If not, comment out the `Authentication` section in the
`docker-compose.yaml`.

## Config

Run `make config`


It will ask to create usernames and passwords, and automatically put the hashes
into the `.env` file for the `INVIDIOUS_HTTP_AUTH` variable. You will use the
username and plain text password to authenticate before loading the app. Note
this does not authenticate you to invidious, but only allows access to the app.
In order to use all of the app features, you must create an invidious account
and log into the app.

## Notes on invidious

The default setting is for clients to stream videos directly from Google. If
this is not desired, make sure you set the setting in the client interface
called `Proxy videos`. Also see [invidious docs on
this](https://github.com/iv-org/documentation/blob/master/Always-use-%22local%22-to-proxy-video-through-the-server-without-creating-an-account.md).

You should create an invidious account and log into the app, in addition to the
HTTP basic auth password. If you don't create an account, and you don't login,
your settings (eg. `Proxy Videos`) are not saved!

