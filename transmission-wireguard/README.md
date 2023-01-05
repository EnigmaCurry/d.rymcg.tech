# transmission-wireguard

This is the [Transmission](https://transmissionbt.com/) Bittorrent
client combined with the [Wireguard](https://www.wireguard.com/) VPN
service. Connect wireguard to your VPN provider and anonymize your
peer connections.

## Setup

### Check file limits

Transmission needs to open a lot of files, so you must set your
**Host** operating system limits appropriately:

```
## Check the current limit for number of open files:
$ ulimit -n
```

If the setting is a number in the low thousands (eg `1024`), you must
raise the limit:

```
## /etc/security/limits.conf
## Add this line on *Host* OS and then reboot:
*                -       nofile          1048576
```

### Gather VPN provider config

Your VPN host must support Wireguard. 

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

 * `TRANSMISSION_TRAEFIK_HOST` - the domain name for the transmission
   client interface (eg. `traefik.example.com`)
 * `TRANSMISSION_DOWNLOAD_VOLUME` - the name of the Docker volume or
   bind-mounted Host path, to store downloads (eg.
   `/storage/downloads`)
 * `TRANSMISSION_WATCH_VOLUME` - the name of the Docker volume or
   bind-mounted Host path, to store torrents (eg. `/storage/torrents`)
 * `TRANSMISSION_VPN_CLIENT_INTERFACE_PRIVATE_KEY` - the `PrivateKey`
   value from your VPN provided config file. (Long text ending with
   `=`)
 * `TRANSMISSION_VPN_CLIENT_INTERFACE_ADDRESS` - the interface
   `Address` value from your VPN provided config file (Could be
   multiple addresses separated by commas, eg.
   `10.65.244.198/32,fc00:bbbb:bbbb:bb01::2:f4c5/128`).
 * `TRANSMISSION_VPN_CLIENT_INTERFACE_PEER_DNS` the interface `DNS`
   value from your VPN provided config file eg `10.64.0.1`.
 * `TRANSMISSION_VPN_CLIENT_PEER_PUBLIC_KEY` - the peer `PublicKey`
   value from your VPN provided config file (Long text ending with
   `=`)
 * `TRANSMISSION_VPN_CLIENT_PEER_ALLOWED_IPS` - the list of address
   ranges that the client should use the VPN for. To use the VPN for
   *all* traffic, enter `0.0.0.0/0,::0/0` (ipv4,ipv6). To use the VPN
   for a single IP, use `x.x.x.x/32`, etc.
 * `TRANSMISSION_VPN_CLIENT_PEER_ENDPOINT` - the VPN provider's host
   address and port, eg `94.198.42.114:51820`
 * `TRANSMISSION_IP_SOURCE_RANGE` - the IP whitelist of clients
   allowed to connect to the transmission client webapp. If you want
   to only rely upon passwords, and to allow every IP address to
   connect, enter `0.0.0.0/0`. Otherwise you should prevent access
   except from a specific range of IP addresses, eg. `192.168.1.1/24`.
 * Enter the required HTTP Basic authentication username and
   passwords. This can be optionally saved to `passwords.json` so that
   `make open` works without a password.

All these client credentials are stored in your `.env` file.

# Deploy

Once configured, deploy it:

```
make install
```

```
make open
```
