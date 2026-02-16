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

## Configure the hidden services

```
d.rymcg.tech make tor config-dist
d.rymcg.tech make tor reconfigure var='TOR_HIDDEN_SERVICES=[["whoami","whoami-default-whoami"]]'
```

## Install

```
d.rymcg.tech make tor install
```

## Assign .onion addresses to your services

```
d.rymcg.tech make tor onion-addresses
```

## Reinstall

After configuring everything, reinstall tor:

```
d.rymcg.tech make tor reinstall
```

## Reconfigure each service

For each service (e.g. `whoami`) configure it for the specific
`.onion` domain for it's hiddne service, and configure it to use the
`web_plain` entrypoint:

```
d.rymcg.tech make whoami reconfigure var=WHOAMI_TRAEFIK_HOST=abcdef34542.......onion
d.rymcg.tech make whoami reconfigure var=WHOAMI_ENTRYPOINT=web_plain
d.rymcg.tech make whoami reinstall
```

## Verify

1. Check Tor container logs for "100% bootstrapped": 

```
d.rymcg.tech make tor logs
```

2. Check Traefik dashboard for `tor-{SERVICE}` routers on `web_plain` entrypoint.
3. Test from Tor Browser: http://abc123...xyz.onion should show the service response.
