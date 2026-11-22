# Local Baikal image

The `ckulka/baikal` images on Docker Hub stop at Baikal `0.10.1`, while
the upstream [sabre-io/Baikal](https://github.com/sabre-io/Baikal)
project has reached `0.13.0`. This image builds a current Baikal from
ckulka's own Dockerfile and supporting files, so no third-party image
tag has to exist.

`docker-compose.yaml` builds it with `build: context: image`; there is
no `image:` reference, so `make install` builds it on the Docker host
the first time and reuses it afterwards. Rebuild after changing
`BAIKAL_VERSION` or `BAIKAL_HOME_ASSISTANT_FIX` with `make build`
(or `make install BUILD=1`).

## Contents

- `Dockerfile` - copy of
  [ckulka/baikal-docker `nginx-php8.2.dockerfile`](https://github.com/ckulka/baikal-docker/blob/master/nginx-php8.2.dockerfile)
  with three changes:
  - the Baikal version is a build arg (`VERSION`, from
    `BAIKAL_VERSION` in `.env`) instead of a hardcoded `0.10.1`
  - the Home Assistant fix is applied to
    `vendor/sabre/dav/lib/CalDAV/Plugin.php` at build time, with both
    checksums asserted so a Baikal version bump cannot silently skip it
  - the image is tagged by compose, not pushed anywhere
  - PHP 8.2 is required: Baikal 0.11.0 dropped PHP 8.1 support.
- `files/` - the supporting files the Dockerfile copies in, taken from the
  ckulka/baikal-docker repo (entrypoint scripts and nginx.conf).
  ckulka's `30-apply-home-assistant-fix.sh` and
  `Plugin-with-home-assistant-fix.php` are not included, because the fix
  is applied in the Dockerfile instead.

## Home Assistant fix

Home Assistant sets the CalDAV `calendar-timezone` property to a bare
timezone identifier, which sabre/dav tries to parse as a VCALENDAR and
fails with `This parser only supports VCARD and VCALENDAR files`
(<https://github.com/ckulka/baikal-docker/issues/231>,
<https://github.com/sabre-io/dav/issues/1318>). The Dockerfile applies
ckulka's one-line fix (use the value directly as a `DateTimeZone`).

Set `BAIKAL_HOME_ASSISTANT_FIX=false` to build without it.

Note that the upstream 0.10.1 image also applies this fix, at container
start, whenever `APPLY_HOME_ASSISTANT_FIX=true` is set. `APPLY_HOME_ASSISTANT_FIX`
is a container environment variable and no longer does anything here.

## Build

```sh
make build            # builds on the Docker host of the current context
make build-force      # same, without the layer cache (pick up new packages)
```

`make install` builds the image only when it does not exist yet; it does
not rebuild an existing one. That means a changed Dockerfile, a new
`BAIKAL_VERSION` or a new `BAIKAL_HOME_ASSISTANT_FIX` needs `make build`
(or `make install BUILD=1`) to take effect. `make build-force` also
refreshes the PHP packages installed with apt; add `--pull` (e.g.
`docker compose build --pull --no-cache`) if the `nginx:1` base image
should be refreshed as well.

The Baikal release zip is self-contained (it includes `vendor/`, which
bundles sabre/dav 4.7.1), so no Composer step is needed.

## Bumping the Baikal version

1. Set `BAIKAL_VERSION` in `.env` (and the `ARG VERSION` default
   in the Dockerfile).
2. Check whether `vendor/sabre/dav/lib/CalDAV/Plugin.php` still needs
   the Home Assistant fix, and update the line numbers and both sha1
   checksums in the Dockerfile. The build fails loudly if they are
   stale, rather than shipping an unpatched file.
3. `make build` and verify `/admin/` and a CalDAV sync.

## If ckulka publishes an image

If `ckulka/baikal` ever ships a release image with the Home Assistant
fix, this local build can go away:

1. In `docker-compose.yaml`, drop `build:` and use
   `image: ckulka/baikal:${BAIKAL_VERSION}` again, with `BAIKAL_VERSION`
   back to an image tag.
2. Restore `APPLY_HOME_ASSISTANT_FIX: "true"` as a container environment
   variable if that image applies the fix at startup rather than baking
   it in.
3. Delete this directory and move any remaining notes to the project
   README.

Do not keep both `image:` and `build:`: when the tag exists in a
registry, a host without the image pulls it instead of building, and
`make pull` replaces the locally built image with the published one.

## Sources

- https://github.com/sabre-io/Baikal/releases
- https://github.com/ckulka/baikal-docker (MIT license)
