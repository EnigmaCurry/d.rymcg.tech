# Jitsi Meet

[Jitsi Meet](https://github.com/jitsi/docker-jitsi-meet) is an open source video
conferencing and screencasting service.

## Configuration

Run `make config` and answer the questions. 

## Port mapping

The website is proxied via Traefik, but the video bridge is directly port mapped
to the Docker host on UDP port 10000, so you must open this port on your
firewall accordingly.

## Start

Run `make install`

The default suggested config requires authentication to create meetings, but
will allow guests to join if they know the URL. If you enabled this
authentication, you will need to create at least one user account to start the
meeting:

```
make user
```

This will print the password you need to enter to become the Host, otherwise
guests will be left waiting until the Host arrives.

Run `make open` to open the website in your browser.
