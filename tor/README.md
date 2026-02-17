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
and TCP) as Tor hidden services. There are two approaches for HTTP
services:

 * **nginx proxy (recommended):** A built-in nginx container proxies
   Tor traffic to Traefik's existing `websecure` entrypoint (port 443)
   with the correct `Host` header and TLS SNI. Your services need zero
   reconfiguration — they keep their existing domain, TLS certificate,
   and middleware.

 * **web_plain (alternative):** Routes directly to Traefik's
   `web_plain` entrypoint (port 8000). Requires reconfiguring each
   service with `TRAEFIK_HOST=<onion>` and
   `TRAEFIK_ENTRYPOINT=web_plain`.

Both the Tor and nginx containers use `network_mode: host`, so they
have direct access to Traefik's ports on localhost.

```
Tor Browser → Tor container (port 80 → 127.0.0.1:<nginx_port>)
                               → nginx container → https://127.0.0.1:443
                                                      → Traefik websecure (routes by Host header)
```

## Initial setup

Run `config` once to create the environment file:

```
d.rymcg.tech make tor config
```

## HTTP hidden services (nginx proxy — recommended)

This approach proxies Tor traffic through a built-in nginx reverse
proxy to Traefik's `websecure` entrypoint. Your services keep their
existing configuration (domain, TLS, middleware) — no changes needed.

### Add a service

Specify the `host` parameter with the service's existing domain name:

```
d.rymcg.tech make tor add-service svc=whoami host=whoami.example.com
```

The name (`whoami`) is an arbitrary label used to generate the `.onion`
address. The `host` is the real domain name that Traefik uses to route
the request.

Optionally, generate a vanity `.onion` address with a custom prefix:

```
d.rymcg.tech make tor add-service svc=whoami host=whoami.example.com prefix=who
```

Prefixes use base32 characters only (a-z, 2-7). Each additional
character takes ~32x longer. For longer prefixes (5+), a quick
benchmark runs first to estimate the wait time. The first run
builds the [mkp224o](https://github.com/cathugger/mkp224o) Docker
image automatically.

You can run `add-service` multiple times to add more services.

### Install

```
d.rymcg.tech make tor install
```

### List services

Wait for bootstrap to complete (`make tor logs`), then list the
configured hidden services and their `.onion` addresses:

```
d.rymcg.tech make tor list-services
```

### Verify

1. Check Tor container logs for "100% bootstrapped":

```
d.rymcg.tech make tor logs
```

2. Test from Tor Browser: `http://abc123...xyz.onion` should show the
   service response.

## HTTP hidden services (web_plain — alternative)

This approach routes Tor port 80 through the `web_plain` Traefik
entrypoint. Each service must be reconfigured with its `.onion`
address and the `web_plain` entrypoint. Use this if you have a
specific reason to avoid the nginx proxy.

### Configure Traefik

Enable the `web_plain` entrypoint and bind it to localhost:

```
d.rymcg.tech make traefik reconfigure var=TRAEFIK_WEB_PLAIN_ENTRYPOINT_ENABLED=true
d.rymcg.tech make traefik reconfigure var=TRAEFIK_WEB_PLAIN_ENTRYPOINT_HOST=127.0.0.1
d.rymcg.tech make traefik reinstall
```

### Add a service

Add an HTTP hidden service (no `host` parameter):

```
d.rymcg.tech make tor add-service svc=whoami
```

### Install and reconfigure

```
d.rymcg.tech make tor install
d.rymcg.tech make tor list-services
```

For each service, copy the `.onion` address and set it as the
project's `TRAEFIK_HOST` and set the `web_plain` entrypoint:

```
d.rymcg.tech make whoami reconfigure var=WHOAMI_TRAEFIK_HOST=abcdef34542.......onion
d.rymcg.tech make whoami reconfigure var=WHOAMI_TRAEFIK_ENTRYPOINT=web_plain
d.rymcg.tech make whoami reinstall
```

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

## Mixing service types

You can add HTTP (nginx), HTTP (web_plain), and TCP hidden services
together. Each entry creates a separate hidden service with its own
`.onion` address:

```
d.rymcg.tech make tor add-service svc=whoami host=whoami.example.com
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

### Client auth with standalone Tor (SSH, ncat, etc.)

Tor Browser handles client auth interactively, but for SSH and other
command-line tools you need a standalone `tor` client with the
credential configured on disk.

1. Install `tor` on the client machine (e.g. `apt install tor` or
   `brew install tor`).

2. Create a directory for client auth keys and add the credential
   from `show-credential`:

```
sudo mkdir -p /etc/tor/onion_auth
echo 'abc123...xyz:descriptor:x25519:PRIVATE_KEY' | sudo tee /etc/tor/onion_auth/myservice.auth_private
sudo chmod 700 /etc/tor/onion_auth
sudo chmod 600 /etc/tor/onion_auth/myservice.auth_private
```

3. Add `ClientOnionAuthDir` to your torrc:

```
echo 'ClientOnionAuthDir /etc/tor/onion_auth' | sudo tee -a /etc/tor/torrc
sudo systemctl restart tor
```

4. Connect through the local Tor SOCKS proxy (port `9050`):

```
ssh -o ProxyCommand='ncat --proxy 127.0.0.1:9050 --proxy-type socks5 %h %p' user@abc123...xyz.onion
```

Note: the standalone `tor` daemon listens on port `9050`, while Tor
Browser uses port `9150`.

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

For automated scheduled backups to S3, see
[backup-volume](../backup-volume#readme).
