# Tor

[Tor](https://support.torproject.org/about-tor/) is a network designed
to improve the privacy and security of the Internet. This particular
configuration is designed for deploying Tor hidden services.

To access your hidden services, you need to use a Tor client, like the
[Tor Browser](https://www.torproject.org/download/).

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

### Why not TLS?

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

## HTTP hidden services

HTTP hidden services route Tor port 80 through the `web_plain` Traefik
entrypoint. Multiple HTTP services can share the same entrypoint
because Traefik routes by `Host` header. Each service controls its own
Traefik router and middleware (basic authentication, etc.).

### Configure the hidden services

Initialize the tor config and add an HTTP hidden service (`["project", "service_instance"]`):

```
d.rymcg.tech make tor config-dist
d.rymcg.tech make tor add-hidden-service svc='["whoami","whoami-default-whoami"]'
```

You can run `add-hidden-service` multiple times to add more services
without replacing existing ones. If a service with the same name
already exists, it will be updated in place.

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

Add a 3-element TCP entry to `TOR_HIDDEN_SERVICES` using
`add-hidden-service`:

```
["name", tor_port, local_port]
```

 * `name` — the hidden service name (used to generate the `.onion` address)
 * `tor_port` — the port exposed on the `.onion` address (e.g., 6667 for IRC)
 * `local_port` — the port on localhost to forward to (e.g., a Traefik entrypoint or any local service)

```
d.rymcg.tech make tor add-hidden-service svc='["irc", 6667, 6697]'
```

TCP hidden services work with any local port, not just Traefik
entrypoints. For example, to expose the host's SSH daemon:

```
d.rymcg.tech make tor add-hidden-service svc='["ssh", 22, 22]'
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
3. Start a local Tor client to get a SOCKS proxy on `127.0.0.1:9050`:

```
tor &
```

4. Test the IRC connection with `ncat`:

```
ncat --proxy 127.0.0.1:9050 --proxy-type socks5 abc123...xyz.onion 6667
```

5. For SSH hidden services, use the `ProxyCommand` option:

```
ssh -o ProxyCommand='ncat --proxy 127.0.0.1:9050 --proxy-type socks5 %h %p' user@abc123...xyz.onion
```

## Mixing HTTP and TCP services

You can add both HTTP and TCP hidden services incrementally. Each
entry creates a separate hidden service with its own `.onion` address:

```
d.rymcg.tech make tor add-hidden-service svc='["whoami","whoami-default-whoami"]'
d.rymcg.tech make tor add-hidden-service svc='["irc", 6667, 6697]'
```

## Removing a hidden service

```
d.rymcg.tech make tor remove-hidden-service name=whoami
d.rymcg.tech make tor reinstall
```
