# CryptPad

[CryptPad](https://cryptpad.org) is an encrypted, open source office
collaboration suite: pads, sheets, documents, presentations, forms,
whiteboards, kanbans, polls, and more. All content is end-to-end 
encrypted; the server only ever stores ciphertext.

## Two domains: main + sandbox

CryptPad is designed to serve its content over two domains. Account
passwords and cryptographic content is handled on the 'main' domain,
while the user interface is loaded on a 'sandbox' domain which can only
access information which the main domain willingly shares. In the event
of an XSS vulnerability in the UI, this system prevents attackers from
gaining access to accounts.

Both domains are served by the **same container** (the server tells
them apart using the `Host` header and applies a restrictive
Content-Security-Policy to the sandbox domain). Both are routed by
Traefik to port 3000, which since CryptPad 2026.10.0 serves both the
HTTP traffic and the websockets (the server's old dedicated websocket
port, 3003, no longer exists). A single wildcard TLS certificate covers
both domains.

> If you only see a white screen in the browser, the sandbox domain is
> almost always the cause: check `CRYPTPAD_SANDBOX_HOST`, its TLS, and
> the `/api/config` output (below).

## Config

```
# configures the default cryptpad instance:
make config
```

or non-interactively:

```
make config-dist
make reconfigure var=CRYPTPAD_TRAEFIK_HOST=pad.example.com
make reconfigure var=CRYPTPAD_SANDBOX_HOST=pad-sandbox.example.com
```

Main variables (see `.env-dist` for all):

| Variable | Description |
|---|---|
| `CRYPTPAD_IMAGE` | Docker image to run (pinned release tag) |
| `CRYPTPAD_TRAEFIK_HOST` | Main domain (hostnames only, HTTPS/443 via Traefik) |
| `CRYPTPAD_SANDBOX_HOST` | Sandbox domain (must differ from the main domain) |
| `CRYPTPAD_INSTALL_ONLYOFFICE` | `yes` to install the office editors (Euro-Office) on first start |
| `CRYPTPAD_ADMIN_EMAIL` | Contact email shown on the `/contact` page |
| `CRYPTPAD_DEFAULT_STORAGE_LIMIT` | Storage limit for new accounts (JS expression, bytes) |
| `CRYPTPAD_MAX_UPLOAD_SIZE` | Max single upload size (JS expression, bytes) |
| `CRYPTPAD_BLOCK_DAILY_CHECK` | Block the server's daily check-in to cryptpad.org |
| `CRYPTPAD_LOG_LEVEL` | `silly`, `verbose`, `debug`, `feedback`, `info`, `warn`, `error` |
| `CRYPTPAD_TIMEZONE` | Timezone inside the container |

A one-shot `config` service renders `config.js` (from
`config/config.template.js`) and `infra.js` (from
`config/infra.template.js`) into the `config` volume on every start, so
changes to these variables take effect after `make install`/`reinstall`.
`config.js` holds the instance settings (storage limits, logging,
paths); `infra.js` holds the network topology required by the rewritten
CryptPad server (2026.10.0 and later): the public origins and the
internal front/core/storage nodes. It also fixes ownership of the
office volumes (see below).

## Install

```
# installs the default cryptpad instance:
make install
```

On **first start**, the container:

1. runs `install-office.sh` if `CRYPTPAD_INSTALL_ONLYOFFICE=yes`
   (downloads the Euro-Office editors, ~2-4GB; the container reports
   *unhealthy* while this happens — expected),
2. runs `npm run build` (regenerates the web assets; this happens on
   every start by design),
3. starts the server.

### First-run onboarding

On first start, if no administrator exists yet, the server generates a
setup token and prints it in the logs:

```
make logs-out service=cryptpad
```

Look for: `Create your first admin account and customize your instance
by visiting https://<main-domain>/install/#<token>`. Visit that URL in
a browser to create the first admin account and customize the instance
(name, logo, enabled apps, mandatory 2FA, close registration). The
setup URL is re-printed on every start until the first admin exists.

> **Migrating from an old (v5) instance:** the volumes are
> layout-compatible and are reused in place (same volume names). Do
> **not** set a `loginSalt` (via `customize/application_config.js`)
> afterwards: existing account keys were derived without a salt and a
> salt would lock out all existing users. If you ever rebuild this
> instance from scratch with no existing accounts, set
> `AppConfig.loginSalt` in `customize/application_config.js` *before*
> the first registration. Admins are now managed in the admin panel,
> not `adminKeys` in config.js.

## Administration

- `/admin/` — administration panel (admin accounts, storage limits,
  broadcasts, stats, help desk).
- `/checkup/` — instance diagnostics page (a good first stop when
  something is wrong).
- `/contact` — contact page (shows `CRYPTPAD_ADMIN_EMAIL`).

## Office apps (Euro-Office)

`CRYPTPAD_INSTALL_ONLYOFFICE=yes` (the default) makes the entrypoint
run `install-office.sh --accept-license --trust-repository` on first
start, which downloads the Euro-Office Document, Sheet, and
Presentation runtimes into the `onlyoffice_dist` volume (config and a
build git clone live in `onlyoffice_conf`). Since CryptPad 2026.10.0
the office apps are based on Euro-Office, a fork of OnlyOffice; the
volumes keep their historical `onlyoffice_*` names. Re-runs are
idempotent (version files are checked).

Euro-Office is **not** open source; by enabling it you accept its
[license](https://github.com/Euro-Office/web-apps/blob/main/LICENSE.txt).

The two `onlyoffice_*` volumes are mounted at paths that do not exist
inside the image, so Docker would create them root-owned; the one-shot
`config` service chowns their top-level directories to the cryptpad
user (4001) on every start to prevent that.

To check or update the installed office version:

```
make shell
./install-office.sh --check
./install-office.sh --accept-license --trust-repository
```

### Legacy sheets (migrating from an old instance)

Old instances (CryptPad 5.x) **bundled** OnlyOffice editor versions
`v1`, `v2b`, `v4`, `v5` in their source tree. Spreadsheets (and OnlyOffice
documents/presentations) created there carry that editor version in their
content, and opening one requires the matching version to be present in the
`onlyoffice_dist` volume. The new image only installs `v9` (the
`oldest_needed_version` default in `onlyoffice.properties`), so on a fresh
instance a legacy document fails with
`Script Error: See browser console for details` (console shows
`window.DocsAPI is undefined`) — the app requests
`/common/onlyoffice/dist/<old-version>/...` and gets a 404.

To support legacy documents, either:

1. copy the old version directories from the previous instance's
   `www/common/onlyoffice/` tree (e.g., `v1`, `v2b`, `v4`, `v5`) into the
   `onlyoffice_dist` volume, or
2. set `oldest_needed_version` in `onlyoffice.properties` (in the
   `onlyoffice_conf` volume) to the oldest version you need (e.g., `v1`)
   and re-run `./install-office.sh --accept-license --trust-repository`
   in the container (downloads all versions from that one up to `v9`;
   several GB).

Migration is **per-document and automatic**: when a logged-in editor opens a
legacy sheet, the matching old editor loads and an initial checkpoint
re-saves the document at the current version (`v9`); the browser shows
"Upgrading your document to the latest version" followed by
"Updated version available, press OK to reload". Afterwards the document
only ever needs `v9`. Anonymous visitors can view legacy documents but
cannot migrate them.

Once every legacy document you care about has been migrated, the old version
directories can be removed from the `onlyoffice_dist` volume to reclaim
disk space (~900MB for `v1`+`v2b`+`v4`+`v5`). A document that was never
migrated becomes unopenable once its editor version is gone, so migrate
first, clean up second.

## Upgrading

Bump `CRYPTPAD_IMAGE` in the instance env file, then:

```
make reinstall
```

The entrypoint re-runs `npm run build` automatically and data formats
are migrated forward in place (watch for `BLOB_PROOFS_MIGRATION` in the
logs after an upgrade of an older dataset).

> **Upgrades across the 2026.10.0 server rewrite are not drop-in.**
> That release replaced the server with a multi-node architecture that
> serves HTTP and websockets on a single port (3000), split the
> configuration into `config.js` + `infra.js`, and replaced the
> OnlyOffice editors with Euro-Office. Upgrading to it (or beyond it)
> requires updating this project's files first: the instance template
> must no longer define the old `/cryptpad_websocket` → port 3003
> router, and the one-shot `config` service must render `infra.js` next
> to `config.js`. Make those changes in the same `make install` as the
> image bump — either direction on its own breaks websockets or the
> server start (the unprivileged entrypoint cannot create a default
> `infra.js` in the root-owned config volume).

## Open

```
# open the app in your browser:
make open
```

## Troubleshooting

- **White screen in the browser** — sandbox domain misconfigured.
  Verify `CRYPTPAD_SANDBOX_HOST` is set, has a valid TLS cert, and
  serves content; verify `/api/config` returns
  `httpUnsafeOrigin`/`httpSafeOrigin` as the two expected https
  origins:
  ```
  curl -sk https://<main-domain>/api/config
  ```
- **`/checkup/` page** — run the built-in diagnostics first.
- **Pop-up blockers** — disable them for the instance; CryptPad opens
  the sandboxed UI in a new window/iframe.
- **Browser rejects `Cross-Origin-Resource-Policy` / COEP headers** —
  the pure-node image sets these headers once, so this should not
  happen; if it does, add a Traefik `headers` middleware with custom
  response headers on the cryptpad routers.
- **Container unhealthy for a long time after first start** — the
  office editor (Euro-Office) download is still in progress; check
  `make logs-out service=cryptpad`.
