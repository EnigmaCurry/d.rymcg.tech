# e2e - end-to-end smoke test / installer for d.rymcg.tech

This directory contains a fully automated end-to-end test of the
d.rymcg.tech ecosystem on a single DigitalOcean droplet. Given a
DigitalOcean API token and a subdomain to own, it provisions
everything from nothing - droplet, DNS, TLS, Traefik, and a sampling
of apps - with zero interaction, and then verifies every app's HTTPS
route from the outside.

It is a smoke test today, but it is structured to grow into an
automatic installer that an end user could employ.

## Suites

The script runs one of two test suites:

- **`full`** - the complete d.rymcg.tech install on a fresh server:
  droplet + DNS + Traefik + self-hosted acme-dns + a sampling of apps,
  verified over HTTPS. The config supplies a domain and subdomain.
- **`workstation`** - sets up *only* the workstation tooling: the
  Docker **CLI** (not the Docker server), uv, the d.rymcg.tech repo and
  CLI on `PATH`. No DNS records, no firewall, no server apps. A
  d.rymcg.tech workstation controls remote Docker servers; it is not
  one itself. Its config asks for no domain.

Both suites host the workstation files under an unprivileged `admin`
user (see below). The sections below describe the `full` suite.

## What the full suite does

1. **provision**: uploads an SSH key, creates a firewall
   (22/80/443, 53 tcp+udp and 2890 for acme-dns), and creates a Debian
   droplet whose cloud-init installs Docker
   (`_scripts/gumdrop_user_data/docker-debian.yaml`). Disables `ufw`
   (the DigitalOcean firewall is the real firewall).
2. **dns**: creates `A` records for the subdomain, its wildcard, and
   the acme-dns names, plus the `NS` delegation for acme-dns - all in
   your DigitalOcean-managed zone via `doctl`.
3. **bootstrap**: turns the droplet into a self-contained
   "sworkstation" (`lib/remote_bootstrap.sh`). The workstation files
   (repo clone, `~/.config`, `~/.ssh`, docker CLI config) live under an
   unprivileged **`admin`** user (in the `sudo` and `docker` groups,
   created by cloud-init with your SSH key). It installs the
   workstation packages and uv, creates an SSH Docker context that
   logs in as **root@localhost** (so host-side operations like
   `make traefik traefik-user` can create system users), adds bash
   shell integration, and clones d.rymcg.tech from a git remote you
   choose (default: the public upstream `master` - i.e. it tests
   exactly what a new user would get). All phases from here on run as
   `admin`; infra provisioning (cloud-init, firewall) runs as root.
4. **rootconfig**: creates the root `.env_{CONTEXT}` non-interactively
   (`make config-dist` + `make reconfigure`), never using the
   interactive wizards.
5. **acme-dns**: installs the self-hosted
   [acme-dns](../acme-dns) server (the TOUR.md path) and waits for it
   to answer DNS and serve its own TLS.
6. **traefik**: configures Traefik with acme.sh + acme-dns and a
   wildcard certificate for `*.SUB.DOMAIN`, registers with acme-dns,
   creates the `_acme-challenge` CNAME automatically, and waits for
   the certificate to go live.
7. **apps**: installs each app non-interactively
   (`config-dist` → `reconfigure` → `override` → `install` → `wait`).
   Default set: whoami, datetime, it-tools, excalidraw, privatebin.
8. **verify**: curls every app's URL from your workstation and checks
   the HTTP code and the served certificate.
9. **summary**: prints a PASS/FAIL table. Exit code 0 = all passed,
   1 = an infrastructure phase failed, 2 = an app failed verification.

The droplet is **kept** by default - it remains a fully usable
sworkstation you can ssh into. Use `destroy` to tear everything down.

## Requirements

* `doctl`, `ssh`, `git`, `jq`, `curl`, `dig`, `openssl` on your PATH.
* **doctl authenticated to your DigitalOcean account** with write
  access. Authenticate once with:

  ```bash
  doctl auth init   # paste a personal access token when prompted
  ```

  The e2e script never takes a token of its own - it uses whatever
  account doctl is logged into, so the token lives only in doctl's
  config. (See DigitalOcean's docs for creating a
  [personal access token](https://docs.digitalocean.com/reference/api/create-personal-access-token/).)
* A domain (or delegated zone) **managed by DigitalOcean DNS** (full
  suite only).
* An SSH public key (`~/.ssh/id_ed25519.pub` by default).

## Usage

Each test is a **named config**. You configure it once (interactive), then
run it; all settings come from the config file, not command-line arguments.
The form is `make <NAME> <action>`:

```bash
## 'd' is the d.rymcg.tech CLI alias (see WORKSTATION_LINUX.md). You can
## also run the tool directly as '_e2e/e2e.sh make myapp config'.

## Configure a full-install test called 'myapp' (interactive wizard):
d e2e make myapp config

## Run it (reads myapp.conf):
d e2e make myapp full

## Configure and run a workstation-only test called 'desk':
d e2e make desk config         # choose the 'workstation' suite
d e2e make desk workstation

## Inspect, re-run a phase, tear down, or purge:
d e2e make myapp status
d e2e make myapp phase traefik
d e2e make myapp destroy       # delete DO resources, keep the config
d e2e make myapp purge         # destroy + delete the local config

## List all configured tests:
d e2e list
```

`config` runs an interactive wizard (script-wizard) that asks for the suite,
region/size/image, SSH key, admin user, git remote/ref, and — for the full
suite — the domain, subdomain, Let's Encrypt CA (staging/production), the
app list, and the apps' IP source range. Answers are written to
`~/.config/d.rymcg.tech/e2e/<NAME>.conf`.

Running `config` again on an existing test doesn't repeat every question. It
opens a menu listing each setting with its current value: pick one to change
it, "Walk through all questions" to redo the whole wizard, then "Save and
exit" (or "Exit without saving"). You can also edit the `.conf` by hand.

Running an action with no config errors and tells you to run `config` first.

A few options can still be passed per-run to override the config:
`--apps LIST`, `--timeout SECS`, `--keep-going`, `--reinstall`, `--reset-env`, `--yes`.

Every run logs everything (including all remote output) to
`~/.config/d.rymcg.tech/e2e/logs/`, and records resource IDs in
`~/.config/d.rymcg.tech/e2e/<NAME>.state` so `destroy` can find them even
if a run dies halfway. All phases are idempotent: re-running the same
command reuses the droplet, DNS records, and env files that already
exist, so resuming after a failure is just re-running it. Use
`--reset-env` to wipe the remote `.env` files and reconfigure from scratch.

## Expected runtime

A first `full` run takes roughly 15-25 minutes: droplet + cloud-init
(~4 min), workstation bootstrap (~4 min), acme-dns + its own
certificate (~2-5 min, DNS propagation dependent), Traefik + wildcard
certificate (~3-6 min), and ~1 min per app. A repeat run on an
existing droplet completes in a few minutes.

## Platform services and functional tests

Some apps need another service before they can work. `lib/platform.sh`
sets these up automatically: selecting an app pulls in its provider
first (see `app_deps` in `e2e.sh`).

| Provider | Set up by e2e | Used by |
|---|---|---|
| step-ca | init (keeps the admin provisioner password it prints once), x509 policy for the test domain, root fingerprint, one-time tokens | mosquitto, nats |
| forgejo | admin + test users (`e2e-admin`, `e2e-member`, `e2e-outsider`), org `e2e` / team `allowed`, OAuth2 apps | oauth2-proxy, woodpecker |
| minio | one bucket and user per consumer | s3-proxy, nextcloud backups |
| sysbox runtime | `sysbox-ce` installed on the droplet | sysbox-systemd |

Values the platform produces (fingerprint, passwords, client secrets,
S3 keys) are kept on the droplet in
`~/.config/d.rymcg.tech/e2e-platform.env` (mode 0600), never locally.
An app's test vars read them as `@platform:<VAR>`.

Once an app's route verifies, its functional tests add their own result
rows (`app:check`):

* **mosquitto** and **nats:** publish/subscribe with step-ca client certs.
  Also checked: a connection without a cert is refused, and an
  unauthorized client is denied.
* **oauth2-proxy:** a second whoami instance (`whoami-oauth`) behind OAuth2,
  driven like a browser by `lib/oauth2_flow.py`:
  * signed out, you are redirected to Forgejo's login;
  * a team member gets in;
  * a Forgejo user outside the team gets 403;
  * spoofed identity headers don't pass.
* **woodpecker:** an org member logs in through Forgejo; an outsider is refused.
* **s3-proxy:** serves an object put into its bucket.
* **nextcloud:** a restic backup's snapshot lands in minio.
* **sysbox-systemd:** runs under `sysbox-runc`, with systemd as PID 1, booted.
* **tor** (optional; add `tor` to the app list): publishes a second whoami
  instance (`whoami-tor`) as a hidden service, through the tor app's nginx
  proxy. A throwaway Tor client on the droplet fetches the `.onion`
  address over the Tor network, and the check confirms whoami answered.
  The instance also admits `127.0.0.1/32`, since the proxy reaches
  Traefik over loopback.

Every app whose route verifies also gets a timezone row (`app:timezone`).
The run sets the root `DEFAULT_TIMEZONE` to `E2E_TIMEZONE` (default
`Pacific/Chatham`, +12:45/+13:45, an offset no container lands on by
accident; edit the `.conf` to change it). Each running container of the
app, across all its instances, is checked:

* **ok:** its `TZ` env matches, and `date +%z` inside it gives the
  expected offset.
* **na:** `TZ` matches, but the image has no `date` to confirm it
  (distroless/scratch).
* **missing:** no `TZ` at all. Database and cache sidecars stay on UTC
  on purpose, so this is counted but doesn't fail.
* **bad:** `TZ` differs, or the image ignores it (typically no tzdata).
  This fails the app.

An app with no `TZ` on any container fails, unless it is itself a
database (`TZ_EXEMPT_APPS` in `lib/platform.sh`). An app with no running
containers reports SKIP. Containers only pick up
a changed timezone when they are recreated, so use `--reinstall` after
changing `E2E_TIMEZONE` on a kept droplet.

Some apps call another app over HTTPS from inside the droplet, so staging
runs need workarounds:
* oauth2-proxy trusts the Let's Encrypt staging roots
  (`OAUTH2_PROXY_EXTRA_CA_CERT_URLS`).
* woodpecker sets `WOODPECKER_FORGEJO_SKIP_VERIFY`.
* The S3 consumers have none, so their checks fail on staging: test
  them with the production CA.

Switching an existing test from staging to production replaces the
staging wildcard cert automatically.

## Notes and caveats

* The droplet firewall admits only `E2E_IP_SOURCERANGE` on the ports
  Traefik doesn't front: ssh, the acme-dns API, and host-published app
  ports (mosquitto 8883, nats 4222). 80/443 stay open; Traefik's
  ipallowlist limits each app.
* `--staging` (the default) uses the Let's Encrypt **staging** CA for
  the Traefik wildcard certificate, so verification accepts untrusted
  chains (it still requires the right subject and a STAGING issuer).
  A `--production` run is the true end-to-end proof: verification
  then requires a fully valid chain (curl without `-k`).
* acme-dns always fetches a **production** Let's Encrypt certificate
  for its own API endpoint, regardless of `--staging`. Repeated runs
  against the same `acme-dns.SUB.DOMAIN` name can hit the duplicate
  certificate rate limit (5/week). Keeping the droplet between runs
  (the default) avoids this entirely.
* The acme-dns registration account is stored in the acme-sh volume
  on the droplet, so `_acme-challenge` CNAMEs remain stable across
  re-runs. If you destroy the Traefik volumes, the next run
  re-registers and updates the CNAME automatically.
* Apps in the default set are "Tier A": a single `*_TRAEFIK_HOST`
  variable and a valid config straight from `.env-dist`. Apps that
  need more get per-app settings in `app_test_vars`, or a platform
  service (above).
* The first `make` invocations on the droplet are slow (image pulls,
  tooling); raise `--timeout` if a small droplet times out in `wait`.
* The droplet is provisioned with `_e2e/user_data_docker_debian.yaml`
  (Docker install plus a small sshd tweak). It disables OpenSSH 10's
  `PerSourcePenalties`, because the e2e flow connects repeatedly while
  the droplet is still booting and the sworkstation ssh's to itself on
  every docker call — both patterns otherwise trip the penalty and get
  connections reset. The droplet sits behind a DigitalOcean firewall,
  so the host-level penalty adds little.
