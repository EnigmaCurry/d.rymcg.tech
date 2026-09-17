# oauth2-proxy

[oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy) is a reverse proxy
and OpenID Connect (OIDC) Relying Party that provides authentication for
downstream applications via Traefik's `forwardAuth` middleware. It is the
d.rymcg.tech replacement for the older, unmaintained
[traefik-forward-auth](https://github.com/thomseddon/traefik-forward-auth).

By default, it delegates authentication to a self-hosted
[Forgejo](../forgejo) instance via OIDC discovery. Any OIDC provider works
(GitHub, Google, Keycloak, etc.); only Forgejo is wired into the config
wizard by default.

## What this container does

- Sits behind Traefik on a dedicated auth subdomain (default
  `auth.${ROOT_DOMAIN}`).
- Registers a Traefik middleware named `forward-auth@docker` that guards
  any app router it's applied to.
- On an unauthenticated request, redirects the user to the upstream OIDC
  provider (Forgejo) to log in.
- On success, sets a session cookie scoped to `.${ROOT_DOMAIN}` so a single
  login covers every app on this server.
- Emits `X-Forwarded-User`, `X-Forwarded-Email`, and `X-Auth-Request-*`
  headers into the request going to the downstream app, so apps can identify
  the logged-in user from a trusted header.

## Configuration

Follow the directions to deploy [forgejo](../forgejo), create a root account,
and login.

Now in this directory (`oauth2-proxy`), run:

```
make config
```

Answer the questions. Defaults are correct in most cases.

The wizard will:
1. Prompt for the auth domain (default `auth.${ROOT_DOMAIN}`) and cookie
   domain (default `${ROOT_DOMAIN}`).
2. Generate a random cookie encryption secret.
3. Prompt for the Forgejo domain (default `git.${ROOT_DOMAIN}`).
4. Open your browser to the Forgejo OAuth2 applications page and ask you
   to register a new OAuth2 application. Use:
   - **Application Name:** the auth host (or anything you like)
   - **Redirect URI:** `https://auth.<your-root-domain>/oauth2/callback`
   - **Confidential:** yes
5. Prompt for the resulting Client ID and Client Secret.

Then install:

```
make install
```

Check logs for errors:

```
make logs
```

## How the middleware is used by apps

Apps that opt in to sentry authentication have this pair of middlewares
applied to their Traefik router:

```
traefik.http.routers.<app>.middlewares=forward-auth@docker,header-authorization-group-<GROUP>@file
```

- `forward-auth@docker` (this container) — identity check. Ensures the
  user has logged in via Forgejo.
- `header-authorization-group-<GROUP>@file` (from
  [traefik](../traefik)) — group membership check. Ensures the
  authenticated user is a member of `<GROUP>` as defined in
  `TRAEFIK_HEADER_AUTHORIZATION_GROUPS`. Managed via `make sentry` in the
  `traefik` directory.

Apps enable this by setting `<APPNAME>_OAUTH2=true` and
`<APPNAME>_OAUTH2_AUTHORIZED_GROUP=<groupname>` in their `.env`, then
reinstalling.

The `X-Forwarded-User` header sent to the app contains the logged-in
user's email address (as reported by Forgejo). Apps that trust this header
can use it to identify the user and enforce their own fine-grained
permissions.

## Logging out

There is no logout endpoint wired up by default. Session cookies expire
after `OAUTH2_PROXY_COOKIE_EXPIRE` (default `12h`).

Logging out of a single-sign-on chain is inherently multi-step (clear the
session cookie here, then also log out of Forgejo, then also invalidate
any downstream app sessions). It's rarely worth implementing well. The
recommended approach is the same as with the old traefik-forward-auth:
don't rely on logout. Manage your session via your browser instead:

 * Use incognito/private windows for a fresh session.
 * Configure your browser to clear cookies on close.
 * Use [Firefox Multi-Account
   Containers](https://support.mozilla.org/en-US/kb/containers) to
   separate identities per tab.

If you truly need server-side session revocation later, oauth2-proxy
supports Redis-backed sessions, which allow deleting a session key to
invalidate it immediately. That doesn't invalidate the user's Forgejo
session, though — they'd get bounced through OIDC and silently re-issued
a new session unless Forgejo also forces re-auth. Deep logout is not
solved by any single component in this chain.

## Step-CA

If you are using a self-hosted certificate authority like
[step-ca](../step-ca), configure the oauth2-proxy container to trust your
root CA certificate. Set these in your `.env_{CONTEXT}` file:

```
OAUTH2_PROXY_STEP_CA_ENABLED=true
OAUTH2_PROXY_STEP_CA_ENDPOINT=https://ca.example.com
OAUTH2_PROXY_STEP_CA_FINGERPRINT=xxxxxxxxxxxxxxxxxxxxxxxx
## Delete all other CAs that came from the alpine ca-certificates:
OAUTH2_PROXY_STEP_CA_ZERO_CERTS=false
```

 * `OAUTH2_PROXY_STEP_CA_ENABLED` must be `true` to turn on this feature.
 * `OAUTH2_PROXY_STEP_CA_ENDPOINT` must be the main URL for your
   [step-ca](../step-ca) instance.
 * `OAUTH2_PROXY_STEP_CA_FINGERPRINT` must be the public fingerprint of
   your Step-CA instance (eg `make inspect-fingerprint`).

You can inspect the trusted CAs list (the container is built from
`scratch` with no userspace tools, so copy the file out first):

```
docker cp oauth2-proxy:/etc/ssl/certs/ca-certificates.crt .
less ca-certificates.crt
```
