# Local Baikal 0.13.0 image

The `ckulka/baikal` images on Docker Hub stop at `0.10.1` (the upstream
[sabre-io/Baikal](https://github.com/sabre-io/Baikal) project has since
reached 0.13.0). This directory contains everything needed to build a
0.13.0 image from ckulka's own Dockerfile.

## Contents

- `Dockerfile` - copy of
  [ckulka/baikal-docker `nginx-php8.2.dockerfile`](https://github.com/ckulka/baikal-docker/blob/master/nginx-php8.2.dockerfile)
  with `ENV VERSION` changed from `0.10.1` to `0.13.0`.
  (PHP 8.2 is required: Baikal 0.11.0 dropped PHP 8.1 support.)
- `files/` - the supporting files the Dockerfile copies in, taken from the
  ckulka/baikal-docker repo (entrypoint scripts, nginx.conf, Home Assistant
  fix plugin). Two files are rebased onto Baikal 0.13.0:
  - `files/docker-entrypoint.d/Plugin-with-home-assistant-fix.php` - the
    same one-line fix (use the `calendar-timezone` value directly as a
    `DateTimeZone` instead of parsing it as a VTIMEZONE VObject, which is
    what Home Assistant's CalDAV sync needs) applied to the 0.13.0
    `vendor/sabre/dav/lib/CalDAV/Plugin.php`. The bug is still present in
    0.13.0 (sabre/dav 4.7.1).
  - `files/docker-entrypoint.d/30-apply-home-assistant-fix.sh` - ckulka's
    script, with the "already fixed" and "pristine" SHA-1 checksums updated
    for the 0.13.0 `Plugin.php`. (The published 0.10.1 image does not even
    contain this script; it was added to the repo afterwards.)
  Only set `APPLY_HOME_ASSISTANT_FIX=true` in the env file if you use Home
  Assistant's CalDAV integration; otherwise the script is a no-op.

The Baikal 0.13.0 release zip is self-contained (includes `vendor/`,
which bundles sabre/dav 4.7.1), so no Composer step is needed.

## Build

```sh
docker build -t ckulka/baikal:0.13.0 image/
```

The image is tagged `ckulka/baikal:0.13.0` so the compose file can keep
using a normal `image:` reference. If ckulka ever publishes an official
0.13.0 to Docker Hub, `docker compose pull` will replace this local tag
with the official image.

## Sources

- https://github.com/sabre-io/Baikal/releases/tag/0.13.0
- https://github.com/ckulka/baikal-docker (MIT license)
