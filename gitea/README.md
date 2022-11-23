# Gitea

[Gitea](https://gitea.com/) is a git repository host, similar to GitHub, but
entirely self-hosted. Gitea also functions as an identity server and OAuth
provider, to facilitate sign-in for other applications, via
[thomseddon/traefik-forward-auth](https://github.com/thomseddon/traefik-forward-auth)

## Configuration

Run `make config` or copy `.env-dist` to
`.env_${DOCKER_CONTEXT}_default`, and edit variables accordingly.

 * `GITEA_TRAEFIK_HOST` to the external domain name forwarded from traefik, eg.
   `git.example.com`

You can add any other [gitea config
variable](https://docs.gitea.io/en-us/config-cheat-sheet/), following the
[environment-to-ini
format](https://github.com/go-gitea/gitea/tree/main/contrib/environment-to-ini),
but make sure you also copy the added variable names to the
`docker-compose.yaml` environment section, otherwise they will not be seen.

## Initial setup

Bring up the service with `make install`, then immediately open the
website domain in your browser (run `make open`) to finish the setup
procedure with the install wizard (READ the folowing notes before
proceeding).

 * DO NOT attempt to customize any of the settings using the install
   wizard. It will all be overwritten later by the values you set in
   your own `.env_${DOCKER_CONTEXT}_default` file.
 * THE ONLY thing you need to do with the install wizard is to create an
   administrator account and password. Click the `Administrator Account
   Settings` link to expand the option, enter the username `root`, enter a
   secure passphrase, enter your email address.
 * Once you've entered the `root` account details, click `Install Gitea`.

It is normal to receive a message of `Bad Gateway` once, right after
install. You must restart the service in order for your
`.env_${DOCKER_CONTEXT}_default` configuration to be fully applied:

```
# Restart gitea to get the config applied:
make reinstall
```

## Notes

Traefik listens for SSH connections on TCP port 2222 and forwards directly to
the builtin Gitea SSH service.
