# Tor

[Tor](https://support.torproject.org/about-tor/) is a network designed
to improve the privacy and security of the Internet. This particular
configuration is designed for deploying Tor hidden services.

To access your hidden services, you need a Tor client. The
[Tor Browser](https://www.torproject.org/download/) can browse hidden
websites directly, and it also provides a SOCKS proxy on
`localhost:9150` for proxying other applications (SSH, IRC, etc.)
through the Tor network.

WARNING: this configuration is experimental and provided as-is.

```
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

## How this works

This config is designed for hosting any of your Traefik services (HTTP
and TCP) as Tor hidden services. You will configure Tor with the list
of services that you want to generate unique `.onion` domains for.
Each of these services will be configured to use the `web_plain`
entrypoint instead of the default `websecure` entrypoint and to listen
on their assigned `.onion` domain. Tor itself will run on your Docker
host network, so it will have access to proxy for the external Traefik
`web_plain` entrypoint, running on `localhost`. Tor services will be
created only for those services that you explicitly configure this
way.

## Configure Traefik

### Why not use TLS?

Tor hidden services provide their own end-to-end encryption between
the Tor Browser and your services. This configuration will generate
random domain names ending in `.onion`. You cannot use your own domain
names. You generally don't use TLS with `.onion` domains.
(Technically, you can use TLS on .onion domains, but Let's Encrypt
does not support it. Because TLS is redundant to the Tor builtin
encryption, TLS is not supported by this config.)

### Enable the web_plain entrypoint

The Tor proxy will connect to Traefik through the `web_plain`
entrypoint (port `8000` by default), and we bind it to `127.0.0.1` to
prevent LAN access:

```
d.rymcg.tech make traefik reconfigure var=TRAEFIK_WEB_PLAIN_ENTRYPOINT_ENABLED=true
d.rymcg.tech make traefik reconfigure var=TRAEFIK_WEB_PLAIN_ENTRYPOINT_HOST=127.0.0.1
d.rymcg.tech make traefik reinstall
```

## Initial setup

Run `config` once to create the environment file:

```
d.rymcg.tech make tor config
```

## HTTP hidden services

HTTP hidden services route Tor port 80 through the `web_plain` Traefik
entrypoint. Multiple HTTP services can share the same entrypoint
because Traefik routes by `Host` header. Each service controls its own
Traefik router and middleware (basic authentication, etc.).

### Configure the hidden services

Add an HTTP hidden service:

```
d.rymcg.tech make tor add-service svc=whoami
```

The name (`whoami`) is an arbitrary label used to generate the `.onion`
address — the actual routing happens when you set the `.onion` address
as the project's `TRAEFIK_HOST`.

You can run `add-service` multiple times to add more services.

### Install

```
d.rymcg.tech make tor install
```

### Reconfigure each service

Wait for bootstrap to complete (`make tor logs`), then list the
configured hidden services and their `.onion` addresses:

```
d.rymcg.tech make tor list-services
```

For each service (e.g. `whoami`) copy the `.onion` address and set it
as its `{PROJECT}_TRAEFIK_HOST` var and set the `web_plain` entrypoint
via the `{PROJECT}_TRAEFIK_ENTRYPOINT` var:

```
d.rymcg.tech make whoami reconfigure var=WHOAMI_TRAEFIK_HOST=abcdef34542.......onion
d.rymcg.tech make whoami reconfigure var=WHOAMI_TRAEFIK_ENTRYPOINT=web_plain
d.rymcg.tech make whoami reinstall
```

The service's own router handles all Traefik middleware (basic auth
etc.) — Tor traffic goes through the same middleware chain as direct
access.

### Verify

1. Check Tor container logs for "100% bootstrapped":

```
d.rymcg.tech make tor logs
```

2. Test from Tor Browser: http://abc123...xyz.onion should show the service response.

## TCP hidden services

TCP hidden services (e.g., IRC) cannot share an entrypoint because
TCP has no `Host` header for routing. Each TCP service needs its own
dedicated Traefik entrypoint, configured as plain TCP (no TLS, since
the Tor circuit provides encryption).

### Configure the TCP service

Configure the TCP service (e.g., `inspircd`) to disable TLS (Tor
provides its own encryption):

```
d.rymcg.tech make inspircd reconfigure var=INSPIRCD_TRAEFIK_TLS=false
d.rymcg.tech make inspircd reinstall
```

### Configure the Tor hidden service

Add a TCP hidden service using `add-service` with the `port`
parameter (`TOR_PORT:LOCAL_PORT`):

 * `svc` — the hidden service name (used to generate the `.onion` address)
 * `TOR_PORT` — the port exposed on the `.onion` address (e.g., 6667 for IRC)
 * `LOCAL_PORT` — the port on localhost to forward to (e.g., a Traefik entrypoint or any local service)

```
d.rymcg.tech make tor add-service svc=irc port=6667:6697
```

TCP hidden services work with any local port, not just Traefik
entrypoints. For example, to expose the host's SSH daemon:

```
d.rymcg.tech make tor add-service svc=ssh port=22:22
```

### Install

```
d.rymcg.tech make tor install
d.rymcg.tech make tor list-services
```

### Verify

1. Check Tor container logs for "100% bootstrapped":

```
d.rymcg.tech make tor logs
```

2. Check Traefik dashboard for the TCP service router on the custom entrypoint.
3. Open [Tor Browser](https://www.torproject.org/download/) and
   connect to the Tor network. Tor Browser provides a SOCKS proxy on
   `127.0.0.1:9150` that other applications can use.

4. Test the IRC connection with `ncat`:

```
ncat --proxy 127.0.0.1:9150 --proxy-type socks5 abc123...xyz.onion 6667
```

5. For SSH hidden services, use the `ProxyCommand` option:

```
ssh -o ProxyCommand='ncat --proxy 127.0.0.1:9150 --proxy-type socks5 %h %p' user@abc123...xyz.onion
```

## Mixing HTTP and TCP services

You can add both HTTP and TCP hidden services incrementally. Each
entry creates a separate hidden service with its own `.onion` address:

```
d.rymcg.tech make tor add-service svc=whoami
d.rymcg.tech make tor add-service svc=irc port=6667:6697
d.rymcg.tech make tor reinstall
```

## Removing a hidden service

```
d.rymcg.tech make tor remove-service name=whoami
d.rymcg.tech make tor reinstall
```

## Client authorization

Tor v3 onion services support client authorization, which restricts
access so only clients with a specific private key can connect. This
uses x25519 keypairs — the public key is placed on the server, and
the private key is given to the client.

### Create a client

```
d.rymcg.tech make tor add-client client=alice
```

### Authorize the client for a service

The hidden service must already be installed (so its directory exists
in the volume):

```
d.rymcg.tech make tor authorize-client svc=whoami client=alice
d.rymcg.tech make tor reinstall
```

You must run `reinstall` after authorizing (or revoking) clients for
changes to take effect.

### Show client credentials

```
d.rymcg.tech make tor show-credential client=alice
```

This displays the private key and, for each authorized service, the
full credential line. Tor Browser will prompt for the private key
when you visit the `.onion` address. For other Tor clients, save the
credential line to a `.auth_private` file in your
`ClientOnionAuthDir`.

### List clients

```
d.rymcg.tech make tor list-clients
d.rymcg.tech make tor list-clients svc=whoami
```

### Revoke access

```
d.rymcg.tech make tor revoke-client svc=whoami client=alice
d.rymcg.tech make tor reinstall
```

### Delete a client entirely

This revokes access from all services and deletes the keypair:

```
d.rymcg.tech make tor remove-client client=alice
d.rymcg.tech make tor reinstall
```

Client keys are stored in the `tor_data` Docker volume and are
included in backups automatically.

## Backup and restore

Your `.onion` addresses are derived from cryptographic keys stored in
the `tor_data` Docker volume. If you lose these keys, your `.onion`
addresses are gone forever. The backup includes both the cryptographic
keys and the `.env` configuration file, so you can restore from
nothing on a fresh host. Back them up to an encrypted archive:

```
d.rymcg.tech make tor backup archive=tor-keys-backup.tar.gz.gpg
```

You will be prompted for a passphrase (AES-256 symmetric encryption).
Store the archive somewhere safe — you will need the same passphrase
to restore.

To restore on the same or a different host:

```
d.rymcg.tech make tor restore archive=tor-keys-backup.tar.gz.gpg
d.rymcg.tech make tor reinstall
```
