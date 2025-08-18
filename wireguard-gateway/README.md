# WireGuard Gateway

This configuration deploys a VPN client gateway to create private
routes across subnets.

If you have several network devices that all need access to the same
WireGuard network, you don't need to install WireGuard clients on all
of them. You can create one gateway, and then give those other devices
a common route to this gateway.

## Config

```
make config
```

Answer the questions to fill in the following config:

  * `WIREGUARD_GATEWAY_LAN_INTERFACE`: Enter the host LAN interface name (check `ip addr`) (eg. eth0)
  * `WIREGUARD_GATEWAY_MAC_ADDRESS`: Enter a random MAC address for the virtual NIC (eg. 02:42:ac:11:00:02)
  * `WIREGUARD_GATEWAY_VPN_INTERFACE`: Enter the VPN interface name (eg. wg0)
  * `WIREGUARD_GATEWAY_CLIENT_ALLOWED_IPS`: Enter the list of allowed client networks (0.0.0.0/0 allows all)

Set all of the variables for the WireGuard config that has been
provisioned by your peer (server):

  * `WIREGUARD_GATEWAY_PRIVATE_KEY`: Enter the WireGuard client's PRIVATE key
  * `WIREGUARD_GATEWAY_PEER_ENDPOINT`: Enter the provided WireGuard peer endpoint (host:port)
  * `WIREGUARD_GATEWAY_PEER_PUBLIC_KEY`: Enter the peer's PUBLIC WireGuard key
  * `WIREGUARD_GATEWAY_PEER_ALLOWED_IPS`: Enter the allowed IPs to forward to the peer
  * `WIREGUARD_GATEWAY_VPN_IPV4`: Enter the VPN client's IPv4 address

## Provision DHCP lease for virtual MAC address

This container needs to bridge to your LAN with a dedicated macvlan
interface (i.e., *not* the interface serving Traefik). macvlan is a
type of virtual interface that will request a local IP address from
your native DHCP server, from the same subnet as your native LAN
interface.

Using the MAC address contained in `WIREGUARD_GATEWAY_MAC_ADDRESS`,
create a static DHCP lease on your router for a LAN IP address to
assign to the macvlan interface. From then on, the container will
always have a dedicated static LAN IP address, to use all for itself.

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
### Add a manual route
The easiest way to create a route on any Linux device is:

```
VPN_NET=10.26.0.0/24
GATEWAY=192.168.1.17
LAN_INTERFACE=eth0
ip route replace ${VPN_NET} via ${GATEWAY} dev ${LAN_INTERFACE}
```

This is a temporary route created manually, it won't survive a reboot.

### Add a static route via DHCP server

The better way to configure a route is via your DHCP server. DHCP
has numbered "options" that provide this:

 * DHCP option 33: Set a *specific* route for a single IP address.
 * DHCP option 121: Set a *general* route for given network CIDR.
 * DHCP option 3: Set the *default* route of your device to use for
   all networks.
   
With any of these options enabled on your DHCP server, when your
device boots up and receives its IP address from your DHCP server, it
will also receive the gateway routing config.

For example, if you are using the `dnsmasq` DHCP server, and you want
to use option 121:

```
dhcp-host=CA:FE:BA:BE:01:02,myclient,192.168.1.5,set:my-vpn
dhcp-option=tag:my-vpn,121,192.168.1.17
```

Or, if you want to set the *default* route:

```
dhcp-host=CA:FE:BA:BE:01:02,myclient,192.168.1.5,set:my-vpn
dhcp-option=tag:my-vpn,3,192.168.1.17
```

Consult your DHCP documentation for more details.

## Tech notes

Note: `macvlan` connections bind directly to your physical LAN, and
are isolated from the host (they act as distinct network adapters),
they work great when contacted by a *different* host, but they have an
inconvenience when trying to create a route from the *same* host. See
https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/
for possible workarounds.
