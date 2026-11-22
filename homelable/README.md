# Homelable

[Homelable](https://github.com/Pouzor/homelable) is a self-hosted homelab
infrastructure visualization, documentation, network scanning and live
monitoring tool. It nmap-scans your network, builds a canvas of your devices,
writes a markdown document for each one, and continuously checks node status.

## Config

```
make config
```

This will ask you for the domain name to use, the backend network mode
(bridge or host, see [Scanning](#scanning)) and its port, and the CIDR
ranges to scan. It automatically saves your responses into the
configuration file `.env_{DOCKER_CONTEXT}_{INSTANCE}`.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

In addition, Homelable has its own **built-in single admin account** (local
mode). `make config` generates a random password and shows it to you once;
record it. The password is stored as a bcrypt hash
(`HOMELABLE_AUTH_PASSWORD_HASH`), which the backend reads from its
environment; there is no in-app password change.

To reset the password: delete the value of `HOMELABLE_AUTH_PASSWORD_HASH`
and run `make config` again. It only regenerates the password when the
hash is blank, and shows the new password to you once. Then run
`make install` so the backend picks up the new hash:

```
make reconfigure var=HOMELABLE_AUTH_PASSWORD_HASH=
make config
make install
```

If you add sentry auth (mTLS / OAuth2 / HTTP Basic Auth) in front of
Homelable, remember that any account that passes the authorization group
gets full access to the app: Homelable's built-in auth cannot check the user
header that oauth2-proxy sends.

### Scanning

The backend's network mode determines what the scanner can see; `make
config` asks you to choose:

- **`bridge`** (default) — the backend stays on the compose network and
  none of its ports are exposed on the Docker host, so there is nothing to
  firewall. The trade-off: MAC addresses come from ARP (layer 2), which a
  container on a bridge network can never see, and the passive mDNS sweep
  (see below) receives no LAN multicast. Without MACs, a device's identity
  drifts whenever its DHCP lease changes.
- **`host`** — the backend joins the Docker host's network. This is the fix
  documented upstream for MAC scanning
  ([INSTALLATION.md](https://github.com/Pouzor/homelable/blob/main/INSTALLATION.md#scanning-from-docker--mac-addresses)),
  and it also lets the mDNS sweep see the LAN. The trade-off: the backend
  binds its port directly on the Docker host with no isolation (see
  [Firewall](#firewall)).

To switch modes later:

```
make reconfigure var=HOMELABLE_NETWORK_MODE=host
make install
```

### Backend port

`HOMELABLE_BACKEND_PORT` (default `8000`) is the port the backend listens
on. In host mode it binds directly on the Docker host, so pick a port that
is free there (another app may already use 8000). In bridge mode it is
only reachable from the other containers of this project, so `make
config` only asks for it in host mode and bridge mode uses 8000.

### Firewall

In host mode the backend — including the login endpoint
(`POST /api/v1/auth/login`) — listens on `HOMELABLE_BACKEND_PORT` on every
interface of the Docker host. Only the Traefik-routed frontend should be
user-reachable, so firewall the port down to the Docker subnets, which is
all the frontend and mcp containers need to reach the backend via
`host.docker.internal`. Those containers are on this project's own compose
network (not the default `docker0` bridge, 172.17.0.0/16), and its subnet
is assigned by Docker and can change when the network is recreated. So
allow Docker's whole default address pool, 172.16.0.0/12. With ufw, for
example (adjust the port):

```
ufw allow from 172.16.0.0/12 to any port 8000 proto tcp
ufw deny any to any port 8000 proto tcp
```

If you set a custom `default-address-pools` in Docker's `daemon.json`,
allow that range instead. `docker network inspect homelable_default
--format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'` shows the subnet the
network has right now.

or an equivalent pfSense/OPNsense rule. In bridge mode the backend is not
exposed on the host at all, so no rule is needed for it.

### mDNS discovery

Alongside the nmap scan, the backend runs a passive mDNS/Bonjour sweep
(Shelly, ESPHome, HomeKit, MQTT, plain HTTP services). mDNS is multicast
(224.0.0.251:5353) and link-local: it does not cross routers by default,
so the sweep only sees devices on the backend's own broadcast domain —
which requires host mode (a bridge container receives no LAN multicast at
all). If your router runs an mDNS relay or reflector (avahi, or a built-in
mDNS reflector, e.g. on pfSense/OPNsense/UniFi), mDNS announcements are
forwarded between VLANs, and mDNS-announcing devices on other VLANs will
show up in scans as well. Devices found via mDNS carry no MAC address, so
they have the same identity-drift caveat as devices on routed VLANs.

Devices on *routed* (non-local) VLANs are still discovered by IP, but ARP
does not cross routers, so they never report a MAC address and their
identity can drift when a DHCP lease changes.

### MCP server

Optional. Off by default (compose profile `mcp`). `make config` asks
whether to enable it and generates the two keys for you. You can also
enable it manually:

```
make reconfigure var=HOMELABLE_MCP_API_KEY=<random>
make reconfigure var=HOMELABLE_MCP_SERVICE_KEY=<random>
make reconfigure var=HOMELABLE_MCP_ENABLED=true
make reconfigure var=HOMELABLE_DOCKER_COMPOSE_PROFILES=default,mcp
make install
```

(`make config` sets `HOMELABLE_DOCKER_COMPOSE_PROFILES` from
`HOMELABLE_MCP_ENABLED`, so keep the two in agreement.)

Disabling it (removing `mcp` from the profiles) also only needs a
normal `make install`: it re-renders the compose override, removes the
mcp container, and blanks the backend's `MCP_SERVICE_KEY`. The keys
stay in the .env file and are re-applied when you re-enable it.

The MCP server listens on `HOMELABLE_MCP_PORT` (default **8001**) on the
Docker host (key-authenticated); `make config` asks for the port when you
enable the server. It is published on the host in either network mode, so
keep it firewalled to your LAN.

Configure an MCP client (e.g. Claude Desktop, Open WebUI) to point at
`http://<docker-host>:<HOMELABLE_MCP_PORT>/mcp/` with an `X-API-Key`
header set to `HOMELABLE_MCP_API_KEY` (shown here with the default port):

```json
{
  "mcpServers": {
    "homelable": {
      "type": "http",
      "url": "http://<docker-host>:8001/mcp/",
      "headers": {
        "X-API-Key": "<HOMELABLE_MCP_API_KEY>"
      }
    }
  }
}
```

The AI can read and modify the topology (list/add/update/delete nodes,
edges, and zones, kick off scans, triage inventory, and work the rack
canvas), so treat the API key as a credential.

### Homepage widget

Optional. Homelable exposes read-only stats at `/api/v1/stats/summary`
(keyed by `X-API-Key` header). `make config` asks whether to enable it
and generates the key for you. You can also enable it manually:

```
make reconfigure var=HOMELABLE_HOMEPAGE_WIDGET_API_KEY=<random>
make reconfigure var=HOMELABLE_HOMEPAGE_WIDGET_ENABLE=true
make install
```

Disabling it (`HOMELABLE_HOMEPAGE_WIDGET_ENABLE=false`) also only
needs a normal `make install`: it drops the widget labels and blanks
the backend's API key, so the stats endpoint rejects all keys. The
key stays in the .env file and is re-applied when you re-enable it.

It shows the node count, how many are online and offline, and the
devices pending triage. It needs `HOMELABLE_HOMEPAGE_LABELS_ENABLE=true`,
since the widget is attached to Homelable's homepage service entry.

Note: the widget calls the public Traefik host, which applies all of this
app's Traefik middlewares, and gethomepage only sends the `X-API-Key`
header. So the widget only works with HTTP Basic Auth, OAuth2 and mTLS
all disabled (gethomepage can't log in or present a client certificate),
and with `HOMELABLE_IP_SOURCERANGE` allowing the homepage server's
address. Homelable's own login still protects the app.

## Install

```
make install
```

## Open

```
make open
```

Finish the installation in the browser: log in as `admin` with the password
generated by `make config`, then trigger a network scan.

## Destroy

```
make destroy
```

This completely removes the containers (and also deletes the `data`
volume, including your scanned device inventory, documents, and canvas
designs). Use `make uninstall` instead if you want to keep the data.
