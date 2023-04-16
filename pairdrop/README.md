# Pairdrop

[Pairdrop](https://github.com/schlagmichdoch/PairDrop) is a webapp
(PWA) to send files and messages from peer to peer.

## Setup

```
make config
make install
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
