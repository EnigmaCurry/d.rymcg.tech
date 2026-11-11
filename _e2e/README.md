# e2e - end-to-end smoke test / installer for d.rymcg.tech

This directory contains a fully automated end-to-end test of the
d.rymcg.tech ecosystem on a single DigitalOcean droplet. Given a
DigitalOcean API token and a subdomain to own, it provisions
everything from nothing - droplet, DNS, TLS, Traefik, and a sampling
of apps - with zero interaction, and then verifies every app's HTTPS
route from the outside.

It is a smoke test today, but it is structured to grow into an
automatic installer that an end user could employ.

## What it does

1. **provision**: uploads an SSH key, creates a firewall
   (22/80/443, 53 tcp+udp and 2890 for acme-dns), and creates a Debian
   droplet whose cloud-init installs Docker
   (`_scripts/gumdrop_user_data/docker-debian.yaml`). Disables `ufw`
   (the DigitalOcean firewall is the real firewall).
2. **dns**: creates `A` records for the subdomain, its wildcard, and
   the acme-dns names, plus the `NS` delegation for acme-dns - all in
   your DigitalOcean-managed zone via `doctl`.
3. **bootstrap**: turns the droplet into a self-contained
   "sworkstation" (`lib/remote_bootstrap.sh`): workstation packages,
   uv, an SSH Docker context pointing at `ssh://localhost`, bash
   shell integration, and a clone of d.rymcg.tech pulled from a git
   remote you choose (default: the public upstream `master` - i.e. it
   tests exactly what a new user would get).
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

* A DigitalOcean account and a [personal access token](https://docs.digitalocean.com/reference/api/create-personal-access-token/)
  with write access.
* A domain (or delegated zone) **managed by DigitalOcean DNS**.
* `doctl`, `ssh`, `git`, `jq`, `curl`, `dig`, `openssl` on your PATH.
* An SSH public key (`~/.ssh/id_ed25519.pub` by default).

## Usage

```bash
export DIGITALOCEAN_ACCESS_TOKEN=dop_v1_...

## Run everything (staging CA by default):
d.rymcg.tech e2e up --domain example.com --subdomain e2e

## ... or standalone:
_e2e/e2e.sh up --domain example.com --subdomain e2e

## Real certificates (Let's Encrypt production):
_e2e/e2e.sh up --domain example.com --subdomain e2e --production

## Test a specific branch or fork:
_e2e/e2e.sh up --domain example.com --subdomain e2e \
    --git-url https://github.com/you/d.rymcg.tech.git --git-ref my-branch

## Re-run a single phase:
_e2e/e2e.sh phase traefik --domain example.com --subdomain e2e

## Inspect / tear down:
_e2e/e2e.sh status --name e2e-e2e
_e2e/e2e.sh destroy --name e2e-e2e --yes
```

Run `_e2e/e2e.sh help` for all options.

Every run logs everything (including all remote output) to
`~/.config/d.rymcg.tech/e2e/logs/`, and records resource IDs in
`~/.config/d.rymcg.tech/e2e/NAME.env` so `destroy` can find them even
if a run dies halfway. All phases are idempotent: re-running `up`
reuses the droplet, DNS records, and env files that already exist,
so resuming after a failure is just re-running the same command.
Use `--reset-env` to wipe the remote `.env` files and reconfigure
from scratch.

## Expected runtime

A first `up` run takes roughly 15-25 minutes: droplet + cloud-init
(~4 min), workstation bootstrap (~4 min), acme-dns + its own
certificate (~2-5 min, DNS propagation dependent), Traefik + wildcard
certificate (~3-6 min), and ~1 min per app. A repeat run on an
existing droplet completes in a few minutes.

## Notes and caveats

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
  need secrets, databases, or OAuth need more per-app configuration
  before they can join the list.
* The first `make` invocations on the droplet are slow (image pulls,
  tooling); raise `--timeout` if a small droplet times out in `wait`.
