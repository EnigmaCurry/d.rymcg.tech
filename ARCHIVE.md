# Image Archive

d.rymcg.tech can archive every Docker image it uses — both pulled and
locally built — into compressed `.tar.gz` files on your workstation.
This lets you restore an entire infrastructure from local files,
without depending on Docker Hub, GitHub Container Registry, or any
other external service being available.

## Why archive?

Container registries go down, images get deleted, tags get overwritten,
and rate limits get enforced at the worst possible times. If you need
to redeploy after a disaster — a dead server, a compromised host, a
datacenter outage — the last thing you want is to discover that half
your images are unreachable.

The archive gives you a complete, verified, offline copy of every
image needed to bring up all ~90 projects from scratch.

## Commands

All image commands are available through the `d.rymcg.tech` CLI.
Every command accepts `--help` for full usage details.

```bash
d.rymcg.tech image-catalog              # list all images across projects
d.rymcg.tech image-build                # build/pull all images on the server
d.rymcg.tech image-archive              # archive all images to local files
d.rymcg.tech image-restore              # restore archived images to the server
```

### Cataloging

Scans every project's `docker-compose.yaml`, `.env-dist`, and
Dockerfiles to produce a manifest of all images: what they are, where
they come from, whether they need building or pulling, and which env
vars control them.

```bash
d.rymcg.tech image-catalog [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--json` | JSON output for tooling |
| `--summary` | Summary statistics only |

### Building

Builds and/or pulls all images on the remote Docker host without
archiving them.

```bash
d.rymcg.tech image-build [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--project=NAME` | Single project only |
| `--pull` | Pull fresh base images before building |
| `--pull-only` | Skip builds, only pull images |
| `--dry-run` | Show what would be built |
| `--verbose` | Show docker command output |

### Archiving

Builds/pulls all images on the remote Docker host, then streams each
one back as a compressed `.tar.gz` archive via SSH. By default, images
that have already been archived are skipped.

> **Note:** Building all ~90 projects' images on the server requires
> 200+ GB of disk space. Use `--delete` to remove each image from the
> server immediately after it is archived, keeping disk usage minimal.
> The recommended invocation for a full archive is:
>
> ```bash
> d.rymcg.tech image-archive --fail-fast --delete --verbose
> ```

```bash
d.rymcg.tech image-archive [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--project=NAME` | Single project only |
| `--delete` | Remove images from server after archiving |
| `--no-cache` | Build without Docker layer cache |
| `--force` | Re-archive even if file already exists |
| `--fail-fast` | Stop on first error |
| `--pull` | Pull fresh base images before building |
| `--pull-only` | Skip builds, only pull images |
| `--dry-run` | Show what would be done |
| `--output-dir=PATH` | Override output directory |
| `--verbose` | Show docker command output |
| `--exclude=NAME` | Exclude a project (can be repeated) |
| `--rebuild-manifest` | Rebuild manifest.json from existing archive files |

### Restoring

Loads archived images back onto a Docker host. Verifies SHA256 hashes
from the manifest before loading each image.

```bash
d.rymcg.tech image-restore [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--project=NAME` | Restore a single project |
| `--dry-run` | Show what would be restored |
| `--archive-dir=PATH` | Load from alternate location |

### Installing without internet

By default, `make install` rebuilds images from source which requires
internet access. To skip the build step and use restored images
directly:

```bash
BUILD=false make install
```

Or set `BUILD=false` in the root `.env_{context}` file to disable
building for the entire context.

## Archive structure

Archives are organized by host architecture:

```
_archive/images/
  x86_64/
    traefik/
      traefik-traefik_latest.tar.gz
      traefik-config_latest.tar.gz
      ...
    whoami/
      traefik_whoami_v1.11.0.tar.gz
    manifest.json
  aarch64/
    ...
    manifest.json
```

The `_archive/` directory is in `.gitignore`. Run the archive once per
architecture to build a multi-arch distribution.

## How it works

1. Runs `image-catalog --json` as its data source.
2. For each project, resolves image names via `docker compose config`
   using `.env-dist` (ensuring builds are generic and reproducible).
3. Runs Makefile `build-hook-pre` targets when present (some projects
   need to generate files before building).
4. Pulls or builds each image on the remote Docker host.
5. Streams `docker save | gzip` over SSH to the workstation.
6. Records metadata (image name, size, SHA256, Docker image ID,
   timestamp) in `manifest.json`.

All scripts share common code via `_scripts/image_lib.py`.
