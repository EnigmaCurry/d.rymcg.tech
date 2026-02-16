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

## Configure Traefik

### Why not TLS?

Tor hidden services provide their own end-to-end encryption between
the Tor Browser and your services. This configuration will generate
random domain names ending in `.onion`. You cannot use your own domain
names. You cannot use TLS with `.onion` domains.

### Enable the web_plain entrypoint

The Tor proxy will connect to Traefik through the `web_plain`
entrypoint, which we bind to `127.0.0.1`:

```
d.rymcg.tech make traefik reconfigure var=TRAEFIK_WEB_PLAIN_ENTRYPOINT_ENABLED=true
d.rymcg.tech make traefik reconfigure var=TRAEFIK_WEB_PLAIN_ENTRYPOINT_HOST=127.0.0.1
d.rymcg.tech make traefik reinstall
```

## HTTP hidden services

HTTP hidden services route Tor port 80 through the `web_plain`
Traefik entrypoint. Multiple HTTP services can share the same
entrypoint because Traefik routes by `Host` header.

### Configure the hidden services

```
d.rymcg.tech make tor config-dist
d.rymcg.tech make tor reconfigure var='TOR_HIDDEN_SERVICES=[["whoami","whoami-default-whoami"]]'
```

### Install

```
d.rymcg.tech make tor install
```

### Assign .onion addresses to your services

```
d.rymcg.tech make tor onion-addresses
```

### Reinstall

After configuring everything, reinstall tor:

```
d.rymcg.tech make tor reinstall
```

### Reconfigure each service

For each service (e.g. `whoami`) configure it for the specific
`.onion` domain for its hidden service, and configure it to use the
`web_plain` entrypoint:

```
d.rymcg.tech make whoami reconfigure var=WHOAMI_TRAEFIK_HOST=abcdef34542.......onion
d.rymcg.tech make whoami reconfigure var=WHOAMI_TRAEFIK_ENTRYPOINT=web_plain
d.rymcg.tech make whoami reinstall
```

### Verify

1. Check Tor container logs for "100% bootstrapped":

```
d.rymcg.tech make tor logs
```

2. Check Traefik dashboard for `tor-{SERVICE}` routers on `web_plain` entrypoint.
3. Test from Tor Browser: http://abc123...xyz.onion should show the service response.

## TCP hidden services

TCP hidden services (e.g., IRC) cannot share an entrypoint because
TCP has no `Host` header for routing. Each TCP service needs its own
dedicated Traefik entrypoint, configured as plain TCP (no TLS, since
the Tor circuit provides encryption).

### Create a custom Traefik entrypoint

Create a plain TCP entrypoint bound to `127.0.0.1` for each TCP
service. Use `TRAEFIK_CUSTOM_ENTRYPOINTS` to define it as a
comma-separated 6-tuple:

```
name, host, port, proxy_protocol_enabled, proxy_protocol_trusted_ips, forwardedHeaders_trustedIPs
```

For example, to create an `irc_tor` entrypoint on port 6696:

```
d.rymcg.tech make traefik reconfigure var='TRAEFIK_CUSTOM_ENTRYPOINTS=irc_tor,127.0.0.1,6696,false,,`
d.rymcg.tech make traefik reinstall
```

### Configure the TCP service

Configure the TCP service (e.g., `inspircd`) to use the new
entrypoint:

```
d.rymcg.tech make inspircd reconfigure var=INSPIRCD_TRAEFIK_ENTRYPOINT=irc_tor
d.rymcg.tech make inspircd reinstall
```

### Configure the Tor hidden service

Add a 3-element TCP entry to `TOR_HIDDEN_SERVICES`:

```
["name", tor_port, traefik_port]
```

 * `name` — the hidden service name (used to generate the `.onion` address)
 * `tor_port` — the port exposed on the `.onion` address (e.g., 6667 for IRC)
 * `traefik_port` — the local Traefik entrypoint port (e.g., 6696)

```
d.rymcg.tech make tor reconfigure var='TOR_HIDDEN_SERVICES=[["irc", 6667, 6696]]'
d.rymcg.tech make tor install
```

### Assign .onion addresses

```
d.rymcg.tech make tor onion-addresses
```

### Reinstall

```
d.rymcg.tech make tor reinstall
```

### Verify

1. Check Tor container logs for "100% bootstrapped":

```
d.rymcg.tech make tor logs
```

2. Check Traefik dashboard for the TCP service router on the custom entrypoint.
3. Connect via a Tor SOCKS proxy (e.g., with `torify` or proxy-aware IRC client):

```
torify irssi -c abc123...xyz.onion -p 6667
```

## Mixing HTTP and TCP services

You can combine HTTP and TCP entries in a single `TOR_HIDDEN_SERVICES`
list. Each entry creates a separate hidden service with its own
`.onion` address:

```
d.rymcg.tech make tor reconfigure var='TOR_HIDDEN_SERVICES=[["whoami","whoami-default-whoami"],["irc",6667,6696]]'
```
