# Pairdrop

[Pairdrop](https://github.com/schlagmichdoch/PairDrop) is a webapp
(PWA) to send files and messages from peer to peer.

## Requirements

For full connectivity between peers on diverse networks (behind
various NAT), you must deploy a TURN server. You may install the
d.rymcg.tech [coturn](../coturn) service to fulfill this requirement.

## Setup

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

## Open

```
make open
```

## Notes

Peers on the same local area network should find each other
automatically and both appear in the app to each other. For peers on
different networks (ie. a desktop at home plus a roaming wireless
phone), you need to pair them via 6 digit code. Pairing also adds a
"trusted" green dot, fwiw. (you can't trust the name, anyone can use
any name they want, but the session id apparently never changes.)

Vanadium on android (grapheneOS) needs to enable WebRTC in the
settings (`Settings -> Privacy and Security -> WebRTC IP handling
policy -> Default`). Fennec works fine out of the box. Both of these
browsers support installing the app (PWA) to the homescreen
(recommended).
