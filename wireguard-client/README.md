# wireguard

[wireguard](https://www.wireguard.com/) is a simple VPN. This configuration uses
the
[linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard)
container.

This is the client configuration. The server configuration is in
[wireguard](../wireguard).


## Config

You will need the specific wireguard peer config generated by the server:

```
make config
```

Copy the details from the config and answer the questions.


## Start

Start the client:

```
make install
```
