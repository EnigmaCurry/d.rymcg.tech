# Forgejo

[Forgejo](https://forgejo.org/) is a git repository host, similar to GitHub, but
entirely self-hosted. Forgejo also functions as an identity server and OAuth
provider, to facilitate sign-in for other applications, via
[traefik-forward-auth](../traefik-forward-auth)

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
 * Once you've entered the `root` account details, click `Install Forgejo`.

It is normal to receive a message of `Bad Gateway` once, right after
install. You must restart the service in order for your
`.env_${DOCKER_CONTEXT}_default` configuration to be fully applied:

```
# Restart forgejo to get the config applied:
make reinstall
```

## Notes

To make sure Traefik listens for SSH connections on TCP port 2222 and
forwards directly to the builtin Forgejo SSH service, your `.env_` file for
Traefik must have `TRAEFIK_SSH_ENTRYPOINT_ENABLED=true`. If you need to
update your Traefik `.env_` file, be sure to run `make install` in the
`traefik` directory again.
