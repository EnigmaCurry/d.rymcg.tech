# WireGuard

This config creates a standalone WireGuard (client) instance. Other
containers may join the network and use it for routing purposes.

```
make config
```

```
make install
```

### Gather your VPN client config

Your VPN service provider must support WireGuard.

For example, Mullvad has a [Wireguard Config
Generator](https://mullvad.net/en/account/#/wireguard-config). This
will generate a wireguard config file containing all of the
information you need:

```
### Example wireguard config file from Mullvad:
### The PrivateKey and PublicKey have been redacted:
[Interface]
PrivateKey = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
Address = 10.65.244.198/32,fc00:bbbb:bbbb:bb01::2:f4c5/128
DNS = 10.64.0.1

[Peer]
PublicKey = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
AllowedIPs = 0.0.0.0/0,::0/0
Endpoint = 103.231.88.2:51820
```

### Config

Run `make config` 

Enter the following information as prompted:

 * `WIREGUARD_VPN_CLIENT_INTERFACE_PRIVATE_KEY` - the `PrivateKey`
   value from your VPN provided config file. (Long text ending with
   `=`)
 * `WIREGUARD_VPN_CLIENT_INTERFACE_IPV4` and
   `WIREGUARD_VPN_CLIENT_INTERFACE_IPV6` - the interface `Address`
   values from your VPN provided config file for both IPv4 and IPv6
   (the wireguard config could list be multiple addresses separated by
   a comma, eg. `10.65.244.198/32,fc00:bbbb:bbbb:bb01::2:f4c5/128`, in
   this example the first is the IPv4 address, the second is the IPv6.
   Don't enter the `/32` or `/128` part, just the part before it).
 * `WIREGUARD_VPN_CLIENT_INTERFACE_PEER_DNS` the interface `DNS`
   value from your VPN provided config file eg `10.64.0.1`.
 * `WIREGUARD_VPN_CLIENT_PEER_PUBLIC_KEY` - the peer `PublicKey`
   value from your VPN provided config file (Long text ending with
   `=`)
 * `WIREGUARD_VPN_CLIENT_PEER_ENDPOINT` - the peer `Endpoint`
   value, which is the VPN provider's host address and port, eg
   `94.198.42.114:51820`

All these client credentials are stored in your `.env` file.

## Example of a container routing through a WireGuard instance

Docker containers may use other containers as their network router:

```
docker run --network=container:wireguard-wireguard-1 ...
```

```
## e.g., in docker-compose.yaml in a different project directory:
service:
  foo:
    image: foo
    network_mode: "container:wireguard-wireguard-1"
```

Substitute `wireguard-wireguard-1` with the container name of your
instance.
