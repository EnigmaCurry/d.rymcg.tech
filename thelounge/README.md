# The Lounge

[TheLounge](https://thelounge.chat/) is a web client/bouncer for IRC.

## Config

```
make config
```

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

```
make install
```

## Create user

```
make create-user
```

Enter the username and password

Restart the service after creating users:

```
make restart
```

## Open

```
make open
```

## Usage

Log into the web app with the username and password you created.

Once logged in, you have to create a connection for each IRC
server/bouncer you want to connect to.

If you want to connect to a Soju bouncer, you can only log into one
server per connection. Set the username as `username/irc.example.com`
where irc.example.com is the IRC server you already configured in
Soju. To log into more than one backend, create separate connections
with alternate usernames `username/other.example.org`. Put your Soju
password as the connection password, no SASL password.
