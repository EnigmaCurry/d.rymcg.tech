# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

__NAME__ is the ops/deployment layer for [d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) — a self-hosting framework built on Docker Compose and Traefik. This repo contains no application code. It stores:

- **Woodpecker CI pipeline config** (pre-rendered YAML)
- **SOPS-encrypted environment files** (one per target server "context")
- **Shell tooling** to manage configs and CI setup interactively

The dependent repo lives at `~/git/vendor/enigmacurry/d.rymcg.tech` and provides the `d` CLI tool used throughout.

## Commands

```bash
make help          # Show available targets
make config        # Interactive wizard: create/update encrypted config for a context
make ci            # Configure Woodpecker CI: activate repo, set secrets
make view          # Decrypt and display a config file
make edit          # Edit a config file in-place via sops
```

The `make ci` command requires `WOODPECKER_SERVER` and `WOODPECKER_TOKEN` environment variables.

## Architecture

### Data flow

1. `make config` → interactive wizard collects SSH details + project configs → encrypts with SOPS/age → writes `config/<context>.sops.env`
2. `make ci` → sets Woodpecker secrets via REST API
3. Woodpecker CI runs the deploy pipeline:
   - **deploy.yaml** (push/manual): pulls the pre-built image, authenticates via OpenBao AppRole to get the age decryption key, decrypts the SOPS env file, deploys services to the remote server over SSH

### Secrets chain

OpenBao (Vault fork) → AppRole auth → fetches age private key from KV → decrypts `config/<context>.sops.env` → env vars drive `d make <project> install` commands. All of this is handled by the `d-rymcg-tech` image's `/entrypoint.sh`.

### Key files

- `admin.sh` — all logic; dispatches to `cmd_config`, `cmd_ci`, `cmd_view`, `cmd_edit`
- `.woodpecker/deploy.yaml` — pipeline config (pre-rendered)
- `config/*.sops.env` — SOPS-encrypted dotenv files, one per context (age encryption)

### Context naming

A "context" is a target server identified by its SSH host alias. The context name determines:
- The config file: `config/<context>.sops.env`
- The age keypair: `~/.config/d.rymcg.tech/keys/sops/<context>.age`

### Dependencies

System tools required: `bash`, `sops`, `age`, `age-keygen`, `curl`, `jq`, `docker`, `git`, and `d.rymcg.tech` on PATH.

## Git

- Woodpecker CI watches this repo; pushing triggers the deploy pipeline
