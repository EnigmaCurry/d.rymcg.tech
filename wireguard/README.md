# WireGuard

This config creates a standalone WireGuard (client) instance to
connect to your external WireGuard peer (server). You may create other
containers on the same host and have them join this same Docker
network, routing all traffic through this instance. A multi-layered
kill switch has been implemented to prevent traffic leakage.

## Config
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


### Create instance

It is recommended to use named instances, that way you can keep track
of the peer name in the instance name itself. Note that when you do
this you must always specify it for all commands (or use `make
switch`):

```
## Create a new instance (e.g., my-vpn-peer-xx-12):

make instance=my-vpn-peer-xx-12 config 
```

Enter the following information as prompted:

 * `WIREGUARD_VPN_CLIENT_INTERFACE_PRIVATE_KEY` - the `PrivateKey`
   value from your VPN provided config file. (Long text ending with
   `=`)
 * `WIREGUARD_VPN_CLIENT_INTERFACE_IPV4` and
   `WIREGUARD_VPN_CLIENT_INTERFACE_IPV6` - the interface `Address`
   values from your VPN provided config file for both IPv4 and IPv6
   (the wireguard config could list be multiple addresses separated by
   a comma, eg. `10.65.244.198/32,fc00:bbbb:bbbb:bb01::2:f4c5/128`, in
   this example the first is the IPv4 address, the second is the
   IPv6.)
 * `WIREGUARD_VPN_CLIENT_INTERFACE_PEER_DNS` the interface `DNS`
   value from your VPN provided config file eg `10.64.0.1`.
 * `WIREGUARD_VPN_CLIENT_PEER_PUBLIC_KEY` - the peer `PublicKey`
   value from your VPN provided config file (Long text ending with
   `=`)
 * `WIREGUARD_VPN_CLIENT_PEER_ENDPOINT` - the peer `Endpoint`
   value, which is the VPN provider's host address and port, eg
   `123.123.123.123:51820`

All these client credentials are stored in the local
`.env_{CONTEXT}_{INSTANCE}` file.


## Install

Install the instance by name:

```
make instance=my-vpn-peer-xx-12 install 
```

### Configure kill-switch service on the Docker host

The upstream wireguard service [does not have an integrated
killswitch](https://github.com/linuxserver/docker-wireguard/issues/139).
This configuration adds its own kill switch mechanisms in two
non-exclusive ways:

 * Kill switch mechanism 1 (Recommended) - Container-level kill
   switch - WireGuard acts as a normal router
 
   * With the wireguard container acting as a router for a given
     docker network. Containers retain their own network namespace,
     and can attach to several docker network at the same time.
     Containers that are added to this network must redefine their
     default routes to point to the wireguard instance IP address.
     These containers must also implement their own firewall rules to
     block access to the original gateway.
    
 * Kill switch mechanism 2 (Inferior fallback) - WireGuard-level kill
   switch - Containers join wireguard namespace via `network_mode`.
       
   * Containers may join the network via the `network_mode` parameter.
     This joins containers into the same network namespace as
     wireguard, so they will have the same IP address as wireguard.
     This mode is not recommended - it is mostly inferior to the
     router model described in mechanism 1, except that it does not
     require as much boilerplate. If a container joins the
     network_mode of wireguard, it will lose connection to its
     original docker network (and won't be able to connect to sidecar
     containers, e.g. databases)

   * The wireguard instance adds a firewall ruleset that denys packets
     from leaking on the native network interfaces (any packet *not*
     destined for the wireguard peer.)

To configure mechanism 1, you will need to configure this in the
various containers that support this wireguard config (e.g.
[firefox](../firefox), [aria2](../aria2), and
[qbittorrent](../qbittorrent)).

To configure mechanism 2, there is a question at the end of the
wireguard installation:

```
## At the end of 'make install':

? Do you want to INSTALL the kill-switch for this WireGuard instance (mullvad-deer-goose)? (Y/n)  Yes
```

You can run `make kill-switch-uninstall` if you wish to remove the
kill-switch later on.

## Verify the VPN is functional

Before using the service, you should verify that your VPN is working:

```
# Check that wireguard is running
make status

# Check the logs, make sure there isn't an error:
make logs

# Exec into the container and check the ip address being used:
# (This should report your VPN connection details, not your local connection)
make shell
curl ifconfig.co/json
```

## Example of a container routing through a WireGuard instance

You can create other Docker containers and have them use this
WireGuard container as its default gateway:

```
docker run --network=container:wireguard_my-vpn-peer-xx-12-wireguard-1 ...
```

Or in Docker Compose:

```
## e.g., in docker-compose.yaml in a different project directory:
service:
  foo:
    image: foo
    network_mode: "container:wireguard_my-vpn-peer-xx-12-wireguard-1"
```

Substitute `wireguard_my-vpn-peer-xx-12-wireguard-1` with the
container name of your running instance. See `make status` to get the
actual name of your container.

## Issues with IPv6

On arm64 I had an issue with ipv6 with this error reported from wireguard:

```
wireguard-wireguard-1    | [#] ip6tables-restore -n
wireguard-wireguard-1    | modprobe: can't load module ip6_tables (kernel/net/ipv6/netfilter/ip6_tables.ko.zst): invalid module format
wireguard-wireguard-1    | ip6tables-restore v1.8.8 (legacy): ip6tables-restore: unable to initialize table 'raw'
```

This may have been a host issue, but I was able to work around it by simply removing ipv6 support in the configuration.

```
## To disable ipv6 In your .env file:

# Don't set an ipv6 address:
WIREGUARD_VPN_CLIENT_INTERFACE_IPV6=
# Remove the ::0/0 from the WIREGUARD_VPN_CLIENT_PEER_ALLOWED_IPS list:
WIREGUARD_VPN_CLIENT_PEER_ALLOWED_IPS=0.0.0.0/0
```
