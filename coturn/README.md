# Coturn

[Coturn](https://github.com/coturn/coturn/) is a TURN and STUN server
to facilitate NAT traversal, useful for peer to peer VoIP, Video, and
gaming services.

## Configure firewall

Coturn requires one TCP port, but needs a wide array of UDP ports, and
so this does not use Traefik proxy, but is bound directly to the host
network instead.

 * Open TCP port `3478`
 * Open UDP port `3478`
 * Open all UDP ports `50000` through `60000`
   * You may modify `--min-port` and `--max-port` in
     [docker-compose.yaml](docker-compose.yaml) to change this range.

## Config

```
make config
```

## Install

```
make install
```

## Test

Get temporary test credentials: `make credentials`.

Use the [Trickle
ICE](https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/)
test page. It should work in Firefox or Chromium, but I have found
better test positive results in Chromium.

 * Remove the default server (`stun.google....`)
 * Enter your TURN server prefixed with `turns:` (e.g.
   `turns:turn.example.com`)
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
