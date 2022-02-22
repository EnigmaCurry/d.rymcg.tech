# Jitsi Meet

[Jitsi Meet](https://github.com/jitsi/docker-jitsi-meet) is an open source video
conferencing and screencasting service.

## Configuration

Run `make config` and answer the questions. 

The default suggested config requires authentication to create meetings, but
will allow guests to join if they know the URL. If you enable this
authentication, you will need to create at least one user account to start the meeting:

```
make user
```

This will print the password you need to enter to become the Host. 

## Start

Run `make install`

Run `make open`
