# Registry Cache

A caching proxy for Docker registries, using
[rpardini/docker-registry-proxy](https://github.com/rpardini/docker-registry-proxy).
Unlike Docker's built-in `registry-mirrors` (which only works for
Docker Hub), this proxy transparently caches pulls from **any**
registry: Docker Hub, ghcr.io, quay.io, gcr.io, etc.

It works as an HTTPS man-in-the-middle proxy. Docker clients connect
to it via `HTTP_PROXY`/`HTTPS_PROXY`, and it intercepts, caches, and
serves registry traffic. A generated CA certificate must be trusted by
each client.

## Setup

```
make config
make install
```

## Configure Docker clients

On each Docker host that should use the cache:

### 1. Install the CA certificate

The proxy generates a CA certificate on first start. Retrieve it from
the proxy and install it on the client:

```bash
# Download the CA cert from the proxy:
curl http://<proxy-host>:3128/ca.crt > /usr/share/ca-certificates/docker_registry_proxy.crt
echo "docker_registry_proxy.crt" >> /etc/ca-certificates.conf
update-ca-certificates --fresh
```

### 2. Configure Docker to use the proxy

```bash
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/http-proxy.conf << EOF
[Service]
Environment="HTTP_PROXY=http://<proxy-host>:3128/"
Environment="HTTPS_PROXY=http://<proxy-host>:3128/"
EOF
```

### 3. Restart Docker

```bash
systemctl daemon-reload
systemctl restart docker.service
```

All image pulls will now go through the cache automatically,
regardless of which registry they come from.

## Upstream authentication

To authenticate to upstream registries (for higher rate limits or
private images), set `REGISTRY_CACHE_AUTH_REGISTRIES` during `make
config`. The format is `hostname:username:password`, space-separated
for multiple registries:

```
auth.docker.io:myuser:mypass ghcr.io:myuser:mytoken
```

Note: Docker Hub authentication uses `auth.docker.io` as the
hostname, not `docker.io` or `registry-1.docker.io`.

## Limitations

 * **Push is not supported** — the proxy is read-only by default
 * **Clients must trust the proxy CA** — each Docker host needs the
   CA certificate installed and the HTTP_PROXY/HTTPS_PROXY configured
 * **Private images become accessible** — any client that can reach
   the proxy can pull cached private images, so restrict network
   access to the proxy accordingly
