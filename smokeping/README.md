# Smokeping

[Smokeping](https://oss.oetiker.ch/smokeping/) is a network latency
measurement tool and for tracking it over time.

## Setup

```
make config
make install
make open
```

Smokeping is preconfigured to ping several DNS providers and other
corporate sites. To use your own targets, edit them in the volume:
`/config/Targets` and then `make restart`.

Wait about 10 minutes for the first data to show up in the interface.
