# Authentication and Authorization

Running `make config` for an app will ask whether or not you want to configure
authentication for your app (on top of any authentication your app provides).
You can configure OpenID/OAuth2, mTLS, or HTTP Basic Authentication (or you
can opt to not install any authentication on top of your app).

OAuth2 uses traefik-forward-auth to delegate authentication to an external
authority (eg. a self-deployed Forgejo instance). Accessing an app though
OAuth2 will require all users to login through that external service first.
Once authenticated, they may be authorized access only if their login id
matches the member list of the predefined authorization group configured for
the app (`<APPNAME>_OAUTH2_AUTHORIZED_GROUP`). Authorization groups are defined
in the Traefik config (`TRAEFIK_HEADER_AUTHORIZATION_GROUPS`) and can be
[created/modified](https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/traefik/README.md#oauth2-authentication)
by running `d make traefik config`, selecting "Config", selecting "Middleware",
and selecting "Oauth2 sentry authorization"
([traefik-forward-auth](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/traefik-forward-auth)
must be installed).

mTLS (Mutual TLS) is an extension of standard TLS where both the client and
server authenticate each other using certificates. Accessing an app through
mTLS will require all users to have a client mTLS certificate installed in
their browser, and the app must be configured to accept that certificate. You
will be prompted to enter one or more CN (Common Name) in a comma-separated
list (a CN is a field in a certificate that typically represents the domain
name of the server or the person/organization to which the certificate is
issued). Only certificates matching one of these CNs will be allowed access to
the app, and users with a valid mTLS certificate will be ensured secure,
two-way encrypted communication, providing enhanced security by verifying both
parties' identities.

For HTTP Basic Authentication, you will be prompted to enter one or more
username/password logins which are stored in that app's `.env_{CONTEXT}_{INSTANCE}`
file. Accessing an app through HTTP Basic Authentication will require all
users to enter a login name and password in their browser, and they may be
authorized access to the app only if their login name and password match one
that you configured for the app. *Note:* Browsers themselves prompt the user
for their login credentials, not a web page; so if someone is using a password
manager, it likely won't be able to automate this type of login.
