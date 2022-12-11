# traefik-forward-auth

[traefik-forward-auth](https://github.com/thomseddon/traefik-forward-auth)
is a Traefik middleware to facilitate OpenID/OAuth2 authentication.
You can use this to login to your applications using an external
account. The default `.env-dist` is setup to use a self-hosted
[gitea](../gitea) instance, but you can also use GitHub with the
commented out example, or use [any other oauth2
provider](https://github.com/thomseddon/traefik-forward-auth/wiki/Provider-Setup).

## Configuration

Follow the directions to deploy [gitea](../gitea), create a root
account and login.

Now in this directory (`traefik-forward-auth`), run:

```
make config
```

Answer the questions to configure the following environment variables:

 * `TRAEFIK_FORWARD_AUTH_HOST` Enter the subdomain name used for
   authentication purposes, eg `auth.example.com`.
 * `TRAEFIK_FORWARD_AUTH_COOKIE_DOMAIN` Enter the root domain the
   authentication cookie will be valid for, eg. `example.com`
 * At this point your web browser will automatically open to the gitea
   page where you can create an OAuth2 app. 
   * Enter the `Application Name`, the same as
     `TRAEFIK_FORWARD_AUTH_HOST`, eg `auth.example.com`.
   * Enter the `Redirect URL`, eg `https://auth.example.com/_oauth`.
   * Copy the Client ID and Secret shown.
 * `TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_ID` enter the
   Client ID shown on the OAuth2 application page in gitea.
 * `TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET` enter
   the Client Secret shown on the OAuth2 application page in gitea.

## Enable Traefik Routes for authentication

You can add authentication to any Traefik router by applying the
middleware: `traefik-forward-auth` (In this example, the name of the
route is `foo`):

```
      - "traefik.http.routers.foo.middlewares=traefik-forward-auth@docker"
```

See the commented out example in
[whoami](../whoami/docker-compose.yaml), it is preset for the domain
auth.whoami.{yourdomain}.
