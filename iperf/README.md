# iperf

[iperf3](https://iperf.fr/iperf-doc.php) is a self-hosted bandwidth
speed test service. This configuration is setup to test the performace
of TCP and/or UDP _through [Traefik](../traefik)_.

## Enable entrypoint(s)

You must configure [traefik](../traefik) to enable the `iperf_tcp`
and/or `iperf_udp` entrypoints. If you are using a sentry host
(wireguard VPN server), you must also configure a Layer 4 route to
your main Docker server.

## Config

```
make config
```

To set the allowed IP address source range, set
`IPERF_IP_SOURCERANGE`. Note: **this setting is ignored for UDP**,
because Traefik does not support UDP middleware.

## Install

```
make install
```

## Test bandwidth

From another client, install the `iperf3` client using your package manager.

To test TCP:

```
iperf3 -c iperf.example.com
```

To test UDP:

```
iperf3 -u -b 1000M -c iperf.example.com
```

Note: the `-b 1000M` sets the target maximum bitrate, which is
_required_ to test UDP, otherwise you may see very slow (<1Mbps)
speeds.
