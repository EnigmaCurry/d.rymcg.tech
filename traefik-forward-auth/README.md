# traefik-forward-auth

[traefik-forward-auth](https://github.com/thomseddon/traefik-forward-auth)
is a Traefik middleware to facilitate OpenID/OAuth2 authentication.
You can use this to login to your applications using an external
account. The default `.env-dist` is setup to use a self-hosted
[gitea](../gitea) instance, but you can also use GitHub with the
commented out example, or use [any other oauth2
provider](https://github.com/thomseddon/traefik-forward-auth/wiki/Provider-Setup).

## Important Security Note

Using OpenID/OAuth2 will require a login to access your app, but it will not
affect what a successfully logged-in person can do in your app. If your app has
built-in authentication and can check the user header that
traefik-forward-auth sends, then your app can limit what the logged-in person
can do in the app. But if your app can't check the user header, or if your app
doesn't have built-in authentication at all, then any person with an account
on your Gitea server can log into your app and have full access.

## Configuration

Follow the directions to deploy [gitea](../gitea), create a root
account, and login.

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
 * `TRAEFIK_FORWARD_AUTH_LOGOUT_REDIRECT` Enter the URL to redirect
   after logging out, eg `https://git.example.com/logout`.

## Enable Traefik Routes for authentication

### d.rymcg.tech configured apps
Many d.rymcg.tech apps have been configured to ask you when you run their
`make config` if you want to configure Oauth2 for them. As an alternative to
running `make config`, you can manually edit your `.env_{INSTANCE}` file for
an app and set the value of `<APPNAME>_OAUTH2` to `yes`. 

### Manually configure any Traefik router
Or you can manually add Oauth2 authentication to any Traefik router by applying the
middleware: `traefik-forward-auth` (In this example, the name of the
route is `foo`):

```
      - "traefik.http.routers.foo.middlewares=traefik-forward-auth@docker"
```

### Configure a d.rymcg.tech app to ask for Oauth2 when running `make config`
To configure a d.rymcg.tech app to ask about Oauth2 when running `make config`
(if it hasn't already been so configured), you'll need to edit the
`.env-dist`, `docker-compose.instance.yaml`, and `Makefile` files.
See the [whoami](../whoami/) app for examples.
 * `.env-dist`
  * Add the following env var to `.env-dist` (and adding the comment is a good idea):
```
# OAUTH2
# Set to `yes` to use OpenID/OAuth2 authentication via the
# traefik-forward-auth service in d.rymcg.tech.
# Using OpenID/OAuth2 will require login to access your app,
# but it will not affect what a successfully logged-in person can do in your
# app. If your app has built-in authentication and can check the user
# header that traefik-forward-auth sends, then your app can limit what the
# logged-in person can do in the app. But if your app can't check the user
# header, or if your app doesn't have built-in authentication at all, then
# any person with an account on your Gitea server can log into your app and
# have full access.
WHOAMI_OAUTH2=no
```
  * (Be sure to change `WHOAMI` to the same prefix as the rest of the env vars in your `.env_{INSTANCE}` file)

 * `Makefile`
  * Add the following line to the recipe for the `config-hook` target:
```
 	@${BIN}/reconfigure_oauth2 ${ENV_FILE} WHOAMI_OAUTH2 default=$$( ${BIN}/dotenv -f ${ENV_FILE} get WHOAMI_OAUTH2 )
```
  * Add ` oauth2=WHOAMI_OAUTH2` to the end of the existing line in the receipe for the `override-hook` target.
  * (For all 3 instances of `WHOAMI_OAUTH2`, be sure to change `WHOAMI` to the same prefix as the rest of the env vars in your `.env_{INSTANCE}` file)
 * `docker-compose.instance.yaml`
  * Add the following line to the `#! ### Standard project vars:` section:
```
#@ enable_oauth2 = data.values.oauth2
```
  * Add the following 3 lines in the `labels` section, *before* the `#! Apply all middlewares (do this at the end!)` line:
```
      #@ if enable_oauth2 == "yes":
      #@ enabled_middlewares.append("traefik-forward-auth@docker")
      #@ end
```

## Logging out

User logout is a multi-phase endevour:

 * The user browses to any authenticated domain + `/_oauth/logout`.
   (eg. `https://whatever.example.com/_oauth/logout`). This deletes
   the `_foward_auth` cookie.
 * Then the user is redirected to the the URL specified by
   `TRAEFIK_FORWARD_AUTH_LOGOUT_REDIRECT`. This redirect will delete
   the cookies for gitea (logging out of gitea): `gitea_incredible`
   and `i_like_gitea`.
 * Finally the user is redirected to the main gitea login page, eg.
   `https://git.example.com/user/login` and is now completely logged
   out.
