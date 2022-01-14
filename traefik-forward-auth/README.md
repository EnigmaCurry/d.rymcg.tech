# traefik-forward-auth

[traefik-forward-auth](https://github.com/thomseddon/traefik-forward-auth) is a
Traefik middleware to facilitate OpenID/OAuth2 authentication. You can use this
to login to your applications using an external account. The default `.env-dist`
is setup to use a self-hosted [gitea](../gitea) instance, but you can also use
GitHub with the commented out example.

## Configuration

Copy `.env-dist` to `.env` and edit these variables:

 * `SECRET` create a secret key string, using `openssl rand -base64 45`.
 * `AUTH_HOST` should be a dedicated sub-domain for the OAuth2 callback URL.
   (eg. `auth.example.com`)
 * `COOKIE_DOMAIN` should be the root domain for all apps. (eg. `example.com`)
 * Edit all the `PROVIDERS_GENERIC_OAUTH_AUTH_*` variables, and replace the
   domain name of your Gitea instance from `git.example.com` to your own.
 * Add your OAuth2 credentials `PROVIDERS_GENERIC_OAUTH_CLIENT_ID` and
   `PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET`. These are provided to you by your
   OAuth2 application page. Create your OAuth2 application and fill in the details:
   * For Gitea, go to https://git.example.com/user/settings/applications
(replace git.example.com with your Gitea instance domain name)
   * For GitHub, go to https://github.com/settings/applications/new
   * When creating the app, enter the callback URL:
https://auth.example.com/_oauth (replace auth.example.com with your `AUTH_HOST`
domain name)


## Enable Traefik Routes for authentication

See the example in [whoami](../whoami/docker-compose.yaml), it is preset for the
domain auth.whoami.{yourdomain}.

Add this docker label to make any route use `traefik-forward-auth` (where the
name of the route is `foo`):

```
      - "traefik.http.routers.foo.middlewares=traefik-forward-auth@docker"
```
