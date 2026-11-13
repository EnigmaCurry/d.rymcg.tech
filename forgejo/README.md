# Forgejo

[Forgejo](https://forgejo.org/) is a git repository host, similar to GitHub, but
entirely self-hosted. Forgejo also functions as an OIDC identity provider, to facilitate
single sign-on for other applications, via
[oauth2-proxy](../oauth2-proxy).

## Configuration

Run `make config` or copy `.env-dist` to
`.env_${DOCKER_CONTEXT}_default`, and edit variables accordingly.

 * `FORGEJO_TRAEFIK_HOST` to the external domain name forwarded from traefik, eg.
   `git.example.com`

You can add any other [forgejo config
variable](https://forgejo.org/docs/latest/admin/config-cheat-sheet/), following the
[environment-to-ini
format](https://codeberg.org/forgejo/forgejo/src/branch/forgejo/contrib/environment-to-ini),
but make sure you also copy the added variable names to the
`docker-compose.yaml` environment section, otherwise they will not be seen.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app. *Note:* You can't add Oauth2 on top of Forgejo because Forgejo
would then try to access itself to see if the user had access to Forgejo, but
it couldn't access itself without access - this recursion wouldn't work.

## Initial setup

The web install wizard is disabled (`INSTALL_LOCK=true`): all settings
come from your `.env_${DOCKER_CONTEXT}_default` file. Bring up the
service with:

```
make install
```

On the first install, this creates the admin account
(`FORGEJO_ADMIN_USER`, default `root`) with a random password, and
prints it once:

```
## Forgejo account ready:
##   URL:      https://git.example.com
##   Username: root
##   Password: xxxxxxxxxxxxxxxxxxxxxxxx
## Save this password now; it is not stored anywhere.
```

Log in with it (`make open`). Later installs leave the account alone.

Manage accounts from the command line:

```
## Set a new random password (e.g. if you lost the root password):
make admin-password

## Create another admin account:
make admin-user
```

## Notes

To make sure Traefik listens for SSH connections on TCP port 2222 and
forwards directly to the builtin Forgejo SSH service, your `.env_` file for
Traefik must have `TRAEFIK_SSH_ENTRYPOINT_ENABLED=true`. If you need to
update your Traefik `.env_` file, be sure to run `make install` in the
`traefik` directory again.

## Migration from GitHub

Forgejo has a builtin feature to migrate individual repositories from
other forges like GitHub. Click the + icon in the upper right and
choose `New migration`. 

If you have a lot of repositories to migrate, this can be automated by
the included [github_migrate](github_migrate) script.

## Webhook route (bypass sentry authorization)

When any sentry authorization method is enabled (mTLS, HTTP Basic, or
OAuth2), external services like GitHub cannot reach Forgejo because
they cannot satisfy the auth requirements. To allow webhook access
without sentry auth, set `FORGEJO_WEBHOOK_HOST` to a separate domain
name:

```
FORGEJO_WEBHOOK_HOST=git-webhook.example.com
```

This creates a second Traefik router on the webhook hostname that:

 * Only accepts `POST` requests to `/api/v1/repos/{owner}/{repo}/mirror-sync`
 * Uses plain HTTPS with no sentry authorization middlewares
 * Still applies the IP allowlist middleware
 * Reuses the same Forgejo backend service

When `FORGEJO_WEBHOOK_HOST` is left blank (the default), no webhook
route is created.

To use this with GitHub mirror-sync webhooks:

 1. Set `FORGEJO_WEBHOOK_HOST` during `make config` (or edit your env
    file directly).
 2. Run `make install` to apply.
 3. Create a DNS record pointing the webhook domain to your Traefik
    server.
 4. Create a Forgejo API token with the `write:repository` scope.
    Note: Forgejo tokens are account-scoped, not repo-scoped, so the
    token grants write access to all repos the account can reach.
    Consider creating a dedicated service account that only has access
    to the repos being mirrored.
 5. In GitHub, add a webhook with the URL:
    `https://git-webhook.example.com/api/v1/repos/{owner}/{repo}/mirror-sync?token=YOUR_TOKEN`

## Reset root password

If you've forgotten your administrator password, you can reset it by
entering the shell of the container:

```
make shell
```

```
## In the forgejo container, reset the admin password:
gitea admin user change-password --username root --password hunter2222
```

Login with the new password, and you will be forced to change it one
more time.
