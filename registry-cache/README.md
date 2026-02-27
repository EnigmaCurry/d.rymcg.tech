# Registry Cache

A Docker Registry v2
[pull-through cache](https://docs.docker.com/docker-hub/mirror/) for
Docker Hub (or any upstream registry). The first pull fetches from
upstream and caches locally; subsequent pulls are served directly from
the cache, avoiding rate limits and reducing bandwidth.

This is separate from the [registry](../registry) project, which is a
full read/write container registry. A pull-through cache is read-only
— push is not supported.

## Setup

```
make config
```

You will be prompted for:

 * **Registry cache domain name** — the Traefik hostname for the
   cache (e.g. `registry-cache.example.com`)
 * **Upstream registry URL** — defaults to
   `https://registry-1.docker.io` (Docker Hub)
 * **Upstream credentials** — optional Docker Hub username/password
   for higher rate limits (or access to private images)
 * **Authentication** — HTTP Basic Auth, OAuth2, or mTLS for
   controlling who can pull through this cache

```
make install
```

## Configure Docker clients

On each Docker host that should use the cache, add the cache as a
registry mirror in `/etc/docker/daemon.json`:

```json
{
  "registry-mirrors": ["https://registry-cache.example.com"]
}
```

Then restart the Docker daemon:

```
sudo systemctl restart docker
```

Now `docker pull` commands for Docker Hub images will go through the
cache automatically.

**Note:** Docker's `registry-mirrors` setting only applies to Docker
Hub (`docker.io`). Pulls from other registries (e.g. `ghcr.io`,
`quay.io`) are not affected.

## Docker Hub credentials

If you configure upstream credentials (Docker Hub username and
password or access token), the cache will authenticate to Docker Hub
on your behalf. This is useful for:

 * Avoiding anonymous pull rate limits (100 pulls/6hr anonymous vs
   200 pulls/6hr authenticated)
 * Accessing private Docker Hub repositories

## Limitations

 * **Push is not supported** — a pull-through cache is read-only
 * **Only mirrors one upstream** — each instance can only cache from a
   single upstream registry URL
 * **Docker `registry-mirrors` only works for Docker Hub** — other
   registries require explicit image path rewrites
