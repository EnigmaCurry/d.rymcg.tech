# wireguard

[wireguard](https://www.wireguard.com/) is a simple VPN. This configuration uses
the
[linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard)
container.


This configuration starts a wireguard server in a container, and maps to the
host port 51820. Client credentials are printed to the log in the form of QR
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

Run `make install` to install the service.


## Connecting the VPN to traefik

TODO
