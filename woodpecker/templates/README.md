# Woodpecker CI Pipeline Templates

Starter `.woodpecker.yaml` templates for common CI/CD workflows with
[Woodpecker CI](https://woodpecker-ci.org/) and
[Forgejo](https://forgejo.org/).

## Quick start

1. Copy a template into your repository root as `.woodpecker.yaml`, or into a
   `.woodpecker/` directory for multi-file pipelines:

   ```bash
   # Single pipeline
   cp docker-build.yaml /path/to/myrepo/.woodpecker.yaml

   # Multi-file (Woodpecker merges all YAML files in .woodpecker/)
   mkdir -p /path/to/myrepo/.woodpecker
   cp docker-build.yaml /path/to/myrepo/.woodpecker/build.yaml
   cp notify.yaml /path/to/myrepo/.woodpecker/notify.yaml
   ```

2. Edit the copied file — replace placeholder values (`git.example.com`,
   `/opt/myapp`, `https://myapp.example.com`, etc.) with your actual hostnames
   and paths.

3. Add required secrets in the Woodpecker UI or CLI (see table below).

4. Push to trigger the pipeline.

## Templates

| Template | Description | Required secrets |
|----------|-------------|------------------|
| [`docker-build.yaml`](docker-build.yaml) | Build a Docker image and push to Forgejo's container registry | `registry_username`, `registry_password` |
| [`docker-compose-deploy.yaml`](docker-compose-deploy.yaml) | Deploy a docker-compose project to a remote host via SSH | `ssh_key`, `deploy_host`, `deploy_user` |
| [`test-service.yaml`](test-service.yaml) | Run HTTP health checks against a deployed service | _(none)_ |
| [`build-and-deploy.yaml`](build-and-deploy.yaml) | Full CI/CD: build, push, deploy, notify on failure | `registry_username`, `registry_password`, `ssh_key`, `deploy_host`, `deploy_user`, `ntfy_url` |
| [`notify.yaml`](notify.yaml) | Send notifications via ntfy.sh on success/failure | `ntfy_url`, optionally `ntfy_token` |

## Setting up secrets

### Via the Woodpecker UI

1. Open your repository in the Woodpecker web interface.
2. Go to **Settings > Secrets**.
3. Add each secret by name and value.

### Via the Woodpecker CLI

```bash
# Install the CLI: https://woodpecker-ci.org/docs/usage/cli
woodpecker secret add \
  --repository myorg/myrepo \
  --name registry_password \
  --value "your-forgejo-token"
```

## Forgejo container registry setup

The `docker-build` and `build-and-deploy` templates push images to Forgejo's
built-in container registry at `git.example.com`.

1. In Forgejo, go to **User Settings > Applications**.
2. Create a new access token with the **`package:write`** scope.
3. Use your Forgejo username as `registry_username` and the token as
   `registry_password`.

Images are pushed to `git.example.com/<owner>/<repo>:<tag>`.

## Server configuration

### Privileged plugins

The `docker-build` and `build-and-deploy` templates use
`woodpeckerci/plugin-docker-buildx`, which requires Docker socket access.
The Woodpecker server must allowlist it:

```ini
# In woodpecker server config / environment:
WOODPECKER_PLUGINS_PRIVILEGED=woodpeckerci/plugin-docker-buildx
```

In d.rymcg.tech, you can set this with:

```bash
d.rymcg.tech make woodpecker reconfigure \
  var=WOODPECKER_PLUGINS_PRIVILEGED=woodpeckerci/plugin-docker-buildx
d.rymcg.tech make woodpecker reinstall
```

## Key CI environment variables

These variables are automatically set by Woodpecker and available in all
pipeline steps:

| Variable | Description |
|----------|-------------|
| `CI_REPO_NAME` | Repository name (e.g., `myapp`) |
| `CI_REPO_OWNER` | Repository owner (e.g., `myorg`) |
| `CI_REPO_DEFAULT_BRANCH` | Default branch name (e.g., `main`) |
| `CI_COMMIT_SHA` | Full commit SHA |
| `CI_COMMIT_BRANCH` | Branch that triggered the build |
| `CI_COMMIT_AUTHOR` | Commit author username |
| `CI_PIPELINE_NUMBER` | Pipeline number |
| `CI_PIPELINE_STATUS` | Pipeline status (`success` or `failure`) |
| `CI_PIPELINE_FORGE_URL` | URL to the commit on the forge |

Full reference:
[Woodpecker CI environment variables](https://woodpecker-ci.org/docs/usage/environment)

## Further reading

- [Woodpecker CI documentation](https://woodpecker-ci.org/docs/intro)
- [Woodpecker pipeline syntax](https://woodpecker-ci.org/docs/usage/workflow-syntax)
- [Woodpecker plugins index](https://woodpecker-ci.org/plugins)
- [Forgejo documentation](https://forgejo.org/docs/latest/)
- [d.rymcg.tech Woodpecker setup](../README.md)
