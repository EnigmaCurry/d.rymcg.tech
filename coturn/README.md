# Coturn

[Coturn](https://github.com/coturn/coturn/) is a TURN and STUN server
to facilitate NAT traversal, useful for peer to peer VoIP, video, and
gaming services.

## Configure firewall

Coturn will share the TCP port of your Traefik entrypoint (websecure,
default `443`) for TLS (TURNS). Additionally, you may need to open
some ports in your firewall, depending on which types of connections
you want to allow:

 * Open UDP port 5349.
 * Open UDP port range `50000` through `60000` (allocation pool for relay peers).
 * Open TCP port 5349 (plain TCP TURN, no TLS).

These ports may be configured in your `.env_{CONTEXT}_{INSTANCE}`
file. Please note that the coturn container is using the `host`
network mode, so ports do not need to be "published" by Docker.

## Config

```
make config
```

## Install

```
make install
```

## Test

Get temporary test credentials: `make credentials` (expire in 4 hours).

Get arbitary expiration for credentials: `TTL_SECONDS=300 make credentials` (expire in 5 minutes)

Get permanent credentials: `make credentials-long` (expire in 100 years)

Use the [Trickle
ICE](https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/)
test page. It should work in Firefox or Chromium, but I have found
better test positive results in Chromium.

 * Remove the default server (`stun.google....`)
 * Enter your TURN server prefixed with `turns:` (e.g.
   `turns:turn.example.com:443?transport=tcp` or )
 * Enter the `TURN username`
 * Enter the `TURN password`
 * Click `Add Server`
 * Click `Gather Candidates`
 
In the output below it, you should see rows with `Type` == `relay`. If
you see `relay` it is working. If you don't see `relay` it is NOT
working. 

If its not working, double check the logs to make sure you are not
getting a 401 unauthorized errror. The password is derived from the
function: `timestamp:username:HMAC(secret, username)` (see
[get-credentials.sh](coturn/get-credentials.sh)).
