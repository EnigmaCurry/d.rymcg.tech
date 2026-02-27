# Registry Cache

A collection of Docker Registry v2
[pull-through caches](https://docs.docker.com/docker-hub/mirror/),
one per upstream registry. Each cache is a standard `registry:2`
container behind Traefik with real TLS certificates (Let's Encrypt or
Step-CA). No custom CA, no MITM, no special client trust
configuration beyond what Traefik already provides.

This is separate from the [registry](../registry) project, which is a
full read/write container registry. A pull-through cache is read-only
— push is not supported.

## Supported registries

 * **Docker Hub** (`docker.io`)
 * **GitHub Container Registry** (`ghcr.io`)
 * **Quay.io** (`quay.io`)
 * **Google Container Registry** (`gcr.io`)
 * **Kubernetes registry** (`registry.k8s.io`)
 * **GitLab Container Registry** (`registry.gitlab.com`)
 * **Amazon ECR Public** (`public.ecr.aws`)
 * **LinuxServer Container Registry** (`lscr.io`)
 * **Codeberg Container Registry** (`codeberg.org`)

## Setup

```
make config
```

You will be prompted to select which registries to cache (using
docker-compose profiles), a hostname for each selected cache, and
authentication settings.

```
make install
```

## Configure Docker clients

### Docker Hub

Add the Docker Hub cache as a registry mirror in
`/etc/docker/daemon.json`:

```json
{
  "registry-mirrors": ["https://dockerhub.registry.example.com"]
}
```

Then restart Docker:

```
sudo systemctl restart docker
```

### Other registries (ghcr.io, quay.io, etc.)

Docker's `registry-mirrors` only applies to Docker Hub. For other
registries, configure containerd mirrors. Create a `hosts.toml` file
for each registry:

```
# /etc/containerd/certs.d/ghcr.io/hosts.toml
server = "https://ghcr.io"

[host."https://ghcr.registry.example.com"]
  capabilities = ["pull", "resolve"]
```

```
# /etc/containerd/certs.d/quay.io/hosts.toml
server = "https://quay.io"

[host."https://quay.registry.example.com"]
  capabilities = ["pull", "resolve"]
```

Repeat for each registry you enabled. Restart containerd after
configuration:

```
sudo systemctl restart containerd
```

## Upstream credentials

To configure credentials for higher rate limits or private image
access, edit the `.env` file and set the `_USERNAME` and `_PASSWORD`
variables for each registry. For Docker Hub, this avoids the anonymous
pull rate limit.

## Cache API

An optional read-only API server reports which images have been cached
in each registry. It runs as an additional service (`api`) and is
always deployed when installed.

### Endpoints

#### `GET /`

Returns full stats including repository and tag details for every
running registry cache:

```json
{
  "registries": {
    "dockerhub": {
      "url": "https://registry-1.docker.io",
      "images": 3,
      "repositories": [
        {"name": "library/nginx", "tags": ["latest", "1.27"]},
        {"name": "library/redis", "tags": ["7-alpine"]}
      ]
    },
    "ghcr": {
      "url": "https://ghcr.io",
      "images": 1,
      "repositories": [
        {"name": "actions/runner", "tags": ["latest"]}
      ]
    }
  },
  "summary": {
    "dockerhub": 3,
    "ghcr": 1,
    "total": 4
  }
}
```

#### `GET /summary`

Returns just the image count per registry (no repository details):

```json
{
  "summary": {
    "dockerhub": 3,
    "ghcr": 1,
    "total": 4
  }
}
```

Registries that are not running (not enabled via profiles) are omitted
from the response.

## Limitations

 * **Push is not supported** — pull-through caches are read-only
 * **One cache per upstream** — each `registry:2` container can only
   mirror a single upstream registry URL
 * **Docker `registry-mirrors` only applies to Docker Hub** — other
   registries require containerd mirror configuration on each client
