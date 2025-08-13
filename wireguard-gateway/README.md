# WireGuard Gateway

This configuration deploys a VPN gateway router and connects the
entire LAN subnet to the WireGuard VPN - any client on your LAN can
access the VPN simply by making a route to this gateway.

## Config

```
make config
```

Answer the questions to fill in the following config:

  * `WIREGUARD_GATEWAY_LAN_INTERFACE`: Enter the host LAN interface name (check `ip addr`) (eg. eth0)
  * `WIREGUARD_GATEWAY_MAC_ADDRESS`: Enter a random MAC address for the virtual NIC (eg. 02:42:ac:11:00:02)
  * `WIREGUARD_GATEWAY_VPN_INTERFACE`: Enter the VPN interface name (make sure it's unique on the host) (eg. wg0)

Set all of the variables for the WireGuard config that has been
provisioned by your peer (server):

  * `WIREGUARD_GATEWAY_PRIVATE_KEY`: Enter the WireGuard client's PRIVATE key
  * `WIREGUARD_GATEWAY_PEER_ENDPOINT`: Enter the provided WireGuard peer endpoint (host:port)
  * `WIREGUARD_GATEWAY_PEER_PUBLIC_KEY`: Enter the peer's PUBLIC WireGuard key
  * `WIREGUARD_GATEWAY_PEER_ALLOWED_IPS`: Enter the allowed IPs to forward to the peer
  * `WIREGUARD_GATEWAY_VPN_IPV4`: Enter the VPN client's IPv4 address

## Provision DHCP lease for virtual MAC address

The container will bridge to your LAN and request a local IP address
from your native DHCP server.

Using the value of `WIREGUARD_GATEWAY_MAC_ADDRESS`, create a static
DHCP lease on your router for a LAN IP address to assign to the
virtual network interface. That way the container will always have a
static LAN IP address.

## Install

```
make install
```

## Check WireGuard status

```
make wg
```

This should produce output like this:

```
interface: wg0
  public key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  private key: (hidden)
  listening port: 41086

peer: yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
  endpoint: 192.168.1.1:51820
  allowed ips: 10.26.0.0/24
  latest handshake: 1 minute, 30 seconds ago      <----- Important
  transfer: 22.41 KiB received, 23.62 KiB sent
  persistent keepalive: every 25 seconds
```

If you see the peer listed with a recent handshake, then your
connection is successful.

## Add routes

On any LAN client, you can create a local route to the gateway and
access any VPN route:

```
DEST_NET=10.26.0.0/24
LAN_IPV4=10.13.14.15
LAN_INTERFACE=eth0
ip route replace ${DEST_NET} via ${LAN_IPV4} dev ${LAN_INTERFACE}
```

Note: `macvlan` connections bind directly to your physical LAN, and
are isolated from the host (they act as distinct network adapters),
they work great when contacted by a *different* host, but they have an
inconvenience when trying to create a route from the *same* host. See
https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/
for possible workarounds.
