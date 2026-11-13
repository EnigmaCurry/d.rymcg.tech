# AGENTS.md

Guidance for AI agents (Claude Code, etc.) working with d.rymcg.tech.

d.rymcg.tech is a collection of Docker Compose projects plus a CLI
for managing remote Docker servers from a workstation. Everything is
run on the workstation; the server only runs containers, reached
through an SSH Docker context.

## Repository conventions

- Each top-level directory is a project (`traefik`, `whoami`,
  `forgejo`, ...). `d.rymcg.tech list` shows them all.
- `<project>/.env-dist` is the config template. Its comments document
  every variable. Read it before you configure a project.
- A configured instance lives in `<project>/.env_<CONTEXT>_<INSTANCE>`
  (`INSTANCE` is `default` unless `instance=` is given). If
  `DRT_ENV_DIR` is set, the file is at
  `$DRT_ENV_DIR/<project>/.env_<CONTEXT>_<INSTANCE>` instead.
- The root `.env_<CONTEXT>` holds context-wide settings such as
  `ROOT_DOMAIN`, `PUBLIC_HTTPS_PORT` and `DEFAULT_TIMEZONE`.
- `<project>/docker-compose.instance.yaml` is a ytt template. Each
  project's `override-hook` (in its `Makefile`) maps `.env` variables
  into it, and it renders to
  `docker-compose.override_<CONTEXT>_<INSTANCE>.yaml`. Traefik labels,
  auth middleware and optional features are mostly here.
- The `.env` files and `passwords.json` hold secrets. Never commit
  them and don't print secret values back to the user without a reason.
- Per-project docs are in `<project>/README.md`. Link to or follow
  them; don't restate them here.

`d.rymcg.tech make <project> <target>` runs a project's make target
from any directory. Use `make <target>` inside a project directory to
do the same thing.

## Inspect before acting

Find out what already exists before asking the user or changing
anything:

```bash
docker context ls                          # contexts; * marks the current one
d.rymcg.tech status                        # running projects on the current context
ls <project>/.env_*                        # existing configs for a project
d.rymcg.tech make <project> status         # containers for one project
d.rymcg.tech make <project> dotenv_get var=VAR_NAME
d.rymcg.tech dotenv_get var=ROOT_DOMAIN    # root .env_<CONTEXT> values
```

If the context is reachable and Traefik is running, the server is
already set up. Go straight to the task.

## Safety rules

- **Never overwrite an existing instance config.** `config-dist`
  copies `.env-dist` over `.env_<CONTEXT>_<INSTANCE>` without asking.
  Check whether that file exists first. If it does, change it with
  `reconfigure` instead, or ask the user.
- **Ask before anything destructive or disruptive:** `destroy`
  (removes volumes), `uninstall`, `reinstall` of a service other people
  depend on, deleting contexts, or changing an existing instance's
  routing, TLS, or auth settings.
- **Things only the user can do:** DNS records, web-UI setup wizards,
  and creating OAuth2 apps at an identity provider. Show them the exact
  values to enter and wait for confirmation.
- **Don't guess domains or IPs.** Read them from the existing config
  or ask.
- Instances with `<PREFIX>_INSTANCE_PROTECTION=true` refuse
  `uninstall`/`destroy`. Don't turn that off to get around it.

## Configuring and installing a service

`make config` runs an interactive wizard that agents can't drive. Use
the non-interactive targets:

```bash
d.rymcg.tech make <project> config-dist                       # only if no .env_<CONTEXT>_<INSTANCE> exists
d.rymcg.tech make <project> reconfigure var=VAR_NAME=value    # one variable per call
d.rymcg.tech make <project> install
```

- `reconfigure` changes one existing variable and errors if the name
  isn't in the file. It doesn't touch anything else.
- `make config` also runs the project's `config-hook`, which may
  generate secrets or derived values, and some projects have other
  setup targets (for example `make traefik traefik-user`). Read the
  project's `Makefile` and README and do those steps yourself, or the
  install may be incomplete.
- Optional components are compose profiles, set by
  `<PREFIX>_DOCKER_COMPOSE_PROFILES`. Change it with `reconfigure`.
- Use `install` to apply config changes; it recreates changed
  containers. Use `reinstall` when you need a clean teardown first,
  for example after changing profiles.
- Add `instance=<name>` to any target to work on a non-default
  instance.

Other per-project targets:

```bash
d.rymcg.tech make <project> logs-out [service=<name>]   # non-interactive logs
d.rymcg.tech make <project> restart service=<name>
d.rymcg.tech make <project> config-render              # render the full compose config
d.rymcg.tech make <project> uninstall                   # remove containers, keep volumes
d.rymcg.tech make <project> destroy                     # remove containers AND volumes
```

## Verifying

- `status` and `logs-out` for the containers.
- Test the HTTPS route from the workstation. Read `PUBLIC_HTTPS_PORT`
  first, since it isn't always 443:

  ```bash
  PORT=$(d.rymcg.tech dotenv_get var=PUBLIC_HTTPS_PORT)
  curl -sSI "https://whoami.example.com:${PORT}"
  ```

  A Traefik default certificate or a 404 means the router didn't
  match. A 401 or a redirect to the login page is expected for
  services behind auth.

## Changing a project (contributors)

1. Edit `.env-dist`, `docker-compose.yaml`,
   `docker-compose.instance.yaml` and the project `Makefile` together:
   a new variable usually needs all of them (the `override-hook` passes
   it to ytt). Document the variable in `.env-dist`.
   Every service sets `TZ=${DEFAULT_TIMEZONE:-Etc/UTC}` (the root
   `DEFAULT_TIMEZONE`, exported by `make`), except database and cache
   sidecars, which stay on UTC. A project that needs its own override
   uses `TZ=${<PREFIX>_TIMEZONE:-${DEFAULT_TIMEZONE:-Etc/UTC}}` with a
   blank `<PREFIX>_TIMEZONE=` in `.env-dist`.
2. Render the config for each option combination you touched (auth on
   and off, each profile, etc.). Use `reconfigure` to flip options and
   `config-render` to check the result:

   ```bash
   d.rymcg.tech make <project> reconfigure var=WHOAMI_OAUTH2=true
   d.rymcg.tech make <project> config-render
   ```

3. Install on a test context or instance (not a production one unless
   the user says so), then verify as above.
4. `_e2e/` has an end-to-end test that builds a server from nothing on
   DigitalOcean. See [_e2e/README.md](_e2e/README.md). It costs money
   and creates DNS records, so only run it when asked.

## Setting up a new server or workstation

For a workstation or server that isn't set up yet, use the readiness
checker. It checks workstation packages, SSH, the Docker context and
Traefik, and prints the next steps for whatever is missing:

```bash
make python-deps                                   # once, installs the Python deps (needs uv)
_scripts/agent_readiness.py check --context NAME   # discovers what it can from ~/.ssh/config
_scripts/agent_readiness.py --help                 # all options
```

Ask the user only for what it can't discover (usually the root
domain and whether the server is `public` or `private`), pass them as
flags, and re-run it until it exits 0. Then install Traefik by
following [traefik/README.md](traefik/README.md), and `whoami` to
check TLS.

## Further documentation

- [README.md](README.md): project overview and service list
- [WORKSTATION_LINUX.md](WORKSTATION_LINUX.md): workstation setup
- [DOCKER.md](DOCKER.md): Docker server setup
- [TOUR.md](TOUR.md): guided first install
- [traefik/README.md](traefik/README.md), [acme-dns/README.md](acme-dns/README.md),
  [forgejo/README.md](forgejo/README.md), [oauth2-proxy/README.md](oauth2-proxy/README.md)
