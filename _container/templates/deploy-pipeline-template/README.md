# __NAME__

Deployment admin for [d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) — stores Woodpecker CI pipeline configs and SOPS-encrypted environment files.

## Prerequisites

- [d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) installed and on your PATH
- [sops](https://github.com/getsops/sops) installed
- [age](https://github.com/FiloSottile/age) installed
- SSH config entry for each target server (used as the context name)

## Age keys

Each context gets its own age keypair. Generate one per context:

```
mkdir -p ~/.config/d.rymcg.tech/keys/sops
age-keygen -o ~/.config/d.rymcg.tech/keys/sops/d1.age
```

Set `SOPS_AGE_KEY_FILE` before running any make target — the key filename
(minus `.age`) is used as the default context name:

```
export SOPS_AGE_KEY_FILE=~/.config/d.rymcg.tech/keys/sops/d1.age
make config
```

You can set this in your shell profile or a `.envrc`.

## Usage

```
make help
```

### Generate a config

```
make config
```

This launches an interactive wizard that:

1. **Derives the AGE public key** from `SOPS_AGE_KEY_FILE` (must be set).
2. **Asks for the context name** — defaults to the key filename. Should match an SSH host alias in `~/.ssh/config`.
3. **Asks for SSH details** — host, port, user (defaults from `ssh -G`).
4. **Runs the root config** — sets `ROOT_DOMAIN` and other base settings.
5. **Loops through project selection** — pick projects to configure, choose instance names, then "Done".
6. **Review step** — re-run config or edit the env file for any configured instance.
7. **Collects and encrypts** — gathers all env vars, encrypts with SOPS, writes to `config/<context>.sops.env`.

The wizard uses a temporary context internally so your existing d.rymcg.tech configs are never overwritten. Temp files are cleaned up automatically.

### View a config

```
make view
```

Decrypts and prints a config file to stdout.

### Edit a config

```
make edit
```

Opens a config file in your `$EDITOR` via `sops edit` for in-place encrypted editing.

## File layout

```
__NAME__/
├── Makefile
├── config/
│   ├── d1.sops.env        # encrypted config per context
│   └── d2.sops.env
└── .woodpecker/
    └── deploy.yaml         # CI pipeline
```
