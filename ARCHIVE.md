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

All image commands are available through the `d.rymcg.tech` CLI:

```bash
d.rymcg.tech image-catalog              # list all images across projects
d.rymcg.tech image-build                # build/pull all images on the server
d.rymcg.tech image-archive              # archive all images to local files
d.rymcg.tech image-restore              # restore archived images to the server
```

Every command accepts `--help` for full usage details.

### Cataloging

```bash
d.rymcg.tech image-catalog              # table view with summary
d.rymcg.tech image-catalog --json       # JSON output for tooling
d.rymcg.tech image-catalog --summary    # summary statistics only
```

Scans every project's `docker-compose.yaml`, `.env-dist`, and
Dockerfiles to produce a manifest of all images: what they are, where
they come from, whether they need building or pulling, and which env
vars control them.

### Building

```bash
d.rymcg.tech image-build                       # build/pull everything
d.rymcg.tech image-build --project=traefik     # single project
d.rymcg.tech image-build --pull                # pull fresh base images
d.rymcg.tech image-build --pull-only           # skip builds, only pull
d.rymcg.tech image-build --dry-run             # show what would be built
d.rymcg.tech image-build --verbose             # show docker command output
```

### Archiving

```bash
d.rymcg.tech image-archive                     # archive everything
d.rymcg.tech image-archive --project=whoami    # single project
d.rymcg.tech image-archive --delete            # remove images from server after archiving
d.rymcg.tech image-archive --no-cache          # build without Docker layer cache
d.rymcg.tech image-archive --force             # re-archive even if file exists
d.rymcg.tech image-archive --fail-fast         # stop on first error
d.rymcg.tech image-archive --pull              # pull fresh base images before building
d.rymcg.tech image-archive --pull-only         # skip builds, only pull
d.rymcg.tech image-archive --dry-run           # show what would be done
d.rymcg.tech image-archive --output-dir=PATH   # override output dir
d.rymcg.tech image-archive --verbose           # show docker command output
```

By default, images that have already been archived are skipped. Use
`--force` to re-archive them. Use `--delete` to free disk space on
the server after each image is saved locally — useful when the remote
host is tight on storage.

### Restoring

```bash
d.rymcg.tech image-restore                     # restore all images
d.rymcg.tech image-restore --project=traefik   # restore a single project
d.rymcg.tech image-restore --dry-run           # show what would be restored
d.rymcg.tech image-restore --archive-dir=PATH  # load from alternate location
```

The restore script verifies SHA256 hashes from the manifest before
loading each image.

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
