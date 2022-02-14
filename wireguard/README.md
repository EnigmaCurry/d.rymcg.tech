# wireguard

[wireguard](https://www.wireguard.com/) is a simple VPN. This configuration uses
the
[linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard)
container.


This configuration starts a wireguard server in a container, and maps to the
host port 51820. Client credentials are printed to the log, in the form of QR
codes. Once the server is up, scan the code with your mobile client, and the VPN
is automatically setup.

You can make all traffic go through the VPN, or be selective
(`WIREGUARD_ALLOWEDIPS`).

## Config

Run `make config` to setup your `.env` file.

 * `WIREGUARD_TRAEFIK_HOST` the domain name of the wireguard server (even if you don't connect it to traefik)
 * `WIREGUARD_HOST_PORT` the wireguard port exposed to the host (eg. `51820`) (same port inside the container)
 * `WIREGUARD_PEERS` the number or the names of the clients to create (eg. client1,client2)
 * `WIREGUARD_SUBNET` the private subnet assigned to the wireguard server and clients (eg. `10.13.16.0`)
 * `WIREGUARD_PEERDNS` set the client DNS server to use (eg. `1.1.1.1`). If set
   to `auto`, use the hosts DNS resolver.
 * `WIREGUARD_ALLOWEDIPS` the allowed IPs will limit which traffic goes through
   the VPN. For example, `0.0.0.0/0, ::0/0` would force ALL traffic to go
   through the VPN, whereas `10.13.16.0/24` would only force the local subnet
   traffic to go through the VPN. Ultimately, its up to the client to configure,
   but this informs the client what its configuration should be.

## Install

Run `make install` to install the service.

## Usage

Make sure you install the wireguard client (including `wg-quick`) with your
package manager.

Run `make client-install` to install the local client (Must specify one of the
names you specified for `WIREGUARD_PEERS`, when asked).

Run `make client-start` to start the local wireguard client connection.

Run `make client-stop` to stop the local wireguard client connection.

## Routes

Wireguard will only setup a route to the private Traefik `vpn` endpoint (TCP
port `442` for TLS, which is not exposed to the internet**. All other routes will
use your regular internet connection.

**Note:** While your client system is connected to the wireguard server, your
system will use the Docker host DNS resolver for **all DNS queries** (except for
specific applications [browsers] coded/configured to use DNS over HTTP/TCP). To
modify the DNS records, you can simply edit the `/etc/hosts` file on the Docker
host system, and they will immediately take effect for the wireguard clients.

For example, if you install the [mailu](../mailu) service, you will need to add
the IP address pointing to your Traefik instance's IP on the `traefik-wireguard`
network:

```
## This is the default Traefik IP address on the traefik-wireguard network:
172.15.0.3      mail.example.com
```
