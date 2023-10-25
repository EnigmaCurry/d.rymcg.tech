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
    * (If you use a non-standard HTTPS port, make sure to include it, eg. `https://auth.example.com:8443/_oauth`.)
    * Click `Create Application`.
   * Copy the Client ID and Secret shown.
 * `TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_ID` enter the
   Client ID shown on the OAuth2 application page in gitea.
 * `TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET` enter
   the Client Secret shown on the OAuth2 application page in gitea.
 * `TRAEFIK_FORWARD_AUTH_LOGOUT_REDIRECT` Enter the URL to redirect
   after logging out, eg `https://git.example.com/logout`.

## Enable sentry authentication for Traefik routes

When you run `make config` for an app, you will be asked whether or
not you want to configure sentry authentication for the app (on top of
any authentication the app provides). You can choose None, Basic
Authentication, or OpenID/OAuth2 through traefik-forward-auth.

OAuth2 uses traefik-forward-auth to delegate authentication to an
external authority (eg. a self-deployed Gitea instance). Accessing
this app will require all users to login through that external service
first. Once authenticated, they may be authorized access only if their
login id matches the member list of the predefined authorization group
configured for the app (eg. `WHOAMI_OAUTH2_AUTHORIZED_GROUP`).
Authorization groups are defined in the Traefik config
(`TRAEFIK_HEADER_AUTHORIZATION_GROUPS`) and can be
[created/modified](https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/traefik/README.md#oauth2-authentication)
by running `make sentry` in the `traefik` directory:

```
cd ~/git/vendor/enigmacurry/d.rymcg.tech/traefik
make sentry
```

Use the interactive menus to create all the groups and users that you
need for all your apps (you can return later to add more). Each app
can only have one group, but many apps can share the same group.
Groups are comprised of email addresses of the users that are members
of that group. The email addresses of the group must match those of
accounts on your Gitea instance (or external OAuth provider).

For example, if you have accounts on your Gitea instance for
`alice@example.com` and `bob@demo.com`, and you only want Alice to be
able to access the `whoami` app, create a new group (eg. `whoami`),
and add `alice@example.com` as the only member of that group. Then
configure the whoami instance to require OAuth2 (eg. set
`WHOAMI_OAUTH2=true` in the whoami .env) and set the group to use too
(eg. `WHOAMI_OAUTH2_AUTHORIZED_GROUP=whoami`), reinstall both Traefik
and the whoami app, and test that only `alice@example.com` can login.

### d.rymcg.tech configured apps
Many d.rymcg.tech apps have been configured to ask you when you run their
`make config` if you want to configure Oauth2 for them. As an alternative to
running `make config`, you can manually edit your `.env_{INSTANCE}` file for
an app and set the value of `<APPNAME>_OAUTH2` to `true`, and
`<APPNAME>_OAUTH2_AUTHORIZED_GROUP` to the name of an authorization group you
created when you ran `make groups` in the `traefik` folder. 

### Manually configure any Traefik router
Or you can manually add Oauth2 authentication to any Traefik router by applying the
middleware: `traefik-forward-auth`, and basic authorization by applying the middleware:
`header-authorizatin-group-AUTHORIZED_GROUP` (be sure to replace AUTHORIZED_GROUP
with the name of an authorization group you created when you ran `make groups` in
the `traefik` folder). In this example, the name of the route is `foo`:

```
      - "traefik.http.routers.foo.middlewares=traefik-forward-auth@docker,header-authorization-group-AUTHORIZED_GROUP@file"
```

### Configure a d.rymcg.tech app to ask for Oauth2 when running `make config`
To configure a d.rymcg.tech app to ask about Oauth2 when running `make config`
(if it hasn't already been so configured), you'll need to edit the
`.env-dist`, `docker-compose.instance.yaml`, and `Makefile` files.
See the [whoami](../whoami/) app for examples.
```
.env-dist
```
* Add the following env vars to `.env-dist` (and adding the comments is a good idea):
```
# OAUTH2
# Set to `true` to use OpenID/OAuth2 authentication via the
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
# In addition to Oauth2 authentication, you can configure basic authorization
# by entering which authorization group can log into your app. You create
# groups of email addresses in the `traefik` folder by running `make groups`. 
WHOAMI_OAUTH2_AUTHORIZED_GROUP=
```
* (Be sure to replace `WHOAMI` with the same prefix as the rest of the env vars in your `.env_{INSTANCE}` file.)

```
Makefile
```
* Add the following line to the recipe for the `config-hook` target:
```
 	@${BIN}/reconfigure_auth ${ENV_FILE} WHOAMI
```
* Add ` oauth2=WHOAMI_OAUTH2 authorized_group=WHOAMI_OAUTH2_AUTHORIZED_GROUP` to the end of the existing line in the receipe for the `override-hook` target.
* (Be sure to replace all instances of `WHOAMI` with the same prefix as the rest of the env vars in your `.env_{INSTANCE}` file.)
```
docker-compose.instance.yaml
```
* Add the following line to the `#! ### Standard project vars:` section:
```
#@ authorized_group = data.values.authorized_group
```
* Add the following 4 lines in the `labels` section, *before* the `#! Apply all middlewares (do this at the end!)` line:
```
      #@ if enable_oauth2:
      #@ enabled_middlewares.append("traefik-forward-auth@docker")
      #@ enabled_middlewares.append("header-authorization-group-{}@file".format(authorized_group))
      #@ end
```

## Logging out

User logout is a multi-phase endeavor:

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

You might call this a "deep logout", and honestly, its kind of hacky.
So, think about it this way: don't use logout, and don't expect your
users to logout. Google never intends for you to logout. When's the
last time you had to login to Stack Overlow? So, why should your
self-hosted docker stack implement logout? Just stay logged in, and
manage your cookies through your web browser's features. You have
several good options when it comes to browser cookie management:

 * Use incognito mode for a quick way to test with a brand new session.
 * Tune your browser settings so that it clears cookies when you close
   it.
 * Use [Firefox Multi-Account
   Containers](https://support.mozilla.org/en-US/kb/containers) so
   that new tabs are created in a new temporary session by default.
 * Use
   [SessionBox](https://microsoftedge.microsoft.com/addons/detail/sessionbox-free-multi-l/hmedjmnkphdghfpnbibnibobaliahhfn)
   on Microsoft Edge, which I am told is similar to Firefox
   Multi-Account containers.

Any of these tools will help the developer or admin to test multiple
accounts, however regular users will not need these, as they are
expected to only have a single gitea account, and it is usually
expected for them to always stay logged in unless the gitea session
and traefik-forward-auth cookies both expire.
