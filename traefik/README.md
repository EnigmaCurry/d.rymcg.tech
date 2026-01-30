# Traefik

[Traefik](https://github.com/traefik/traefik) is a modern TLS / HTTP /
TCP / UDP reverse proxy and load balancer. Traefik is the front-most
gateway for (almost) all of the projects hosted by d.rymcg.tech, and
should be the first thing you install in your deployment.

## Config

Open your terminal, and change to this directory (`traefik`).

Run the interactive configuration wizard:

```
make config
```

You are presented an interactive menu to configure Traefik:

```
? Traefik:
> Config
  Install (make install)
  Admin
  Exit (ESC)
```


Go into the `Config` sub-menu, go down the list. You don't necessarily
have to visit all of the menus, but here are the most important ones
to configure:

 * `Traefik user`
   * Traefik needs limited, but privileged, access to your Docker
     host. Rather than run as root, you must create a new `traefik`
     user account for it to use instead.
 * `Entrypoints`
   * `Configure stock entrypoints`
     * `dashboard` - Optionally, enable the Traefik Dashboard, and set a
       username/password for it.
 * `TLS certificates and authorities`
   * `Configure ACME`
   * `Configure TLS certificates`

Once you've gone through the config menus and made your choices,
double check that the config has now been created in your
`.env_${DOCKER_CONTEXT}_default` file, and make any final edits by
hand (there are a few settings that are not covered by the wizard).
The menu config program's sole job is to edit this file for you, but
any edits you make by hand will take precedence. Also note that you
can re-run `make config` anytime, and it will read your choices from
the this file, and make those your default answers.

Once you're happy with the config, install Traefik:

```
make install
```

(You may also choose the `Reinstall Traefik` option directly from the
`make config` menu.)

Check the Traefik logs for any errors:

```
make logs
```

(You may also choose the `Admin` -> `Review Logs` option in the `make
config` menu.)

Open the Traefik dashboard (optional):

```
make open
```

Now go install the [whoami](../whoami) service, watch the traefik log
for any errors, test that the service works, and see that it shows up
in the dashboard.

## ACME

ACME is a protocol that provides for automatic TLS certificate
provisioning. In this config, you have four options regarding ACME:

 1. Acme.sh client + ACME-DNS + (Let's Encrypt or Step-CA)
 2. Traefik builtin ACME client + Let's Encrypt
 3. Traefik builtin ACME client + Step-CA
 4. Disable ACME client.

### Acme.sh + ACME-DNS

If you enable Acme.sh, a sidecar container will start with
[acme.sh](https://github.com/acmesh-official/acme.sh?tab=readme-ov-file)
installed which is an external ACME client. This replaces the Traefik
builtin ACME client. All TLS certificates will be issued/renewed by
acme.sh and traefik will be automatically restarted as needed.

Benefits and/or drawbacks of this method:

 * By using ACME-DNS you avoid a security problem where you need to
   store the API credentials for your domain's primary DNS server.
   With ACME-DNS you delegate the authoritative DNS server to a
   secondary DNS server. It automatically generates its own
   credentials that are guaranteed to be scoped only to allow updates
   to the TXT records of the specific challenge domain.
 * Only supports DNS-01 challenge type, which is a necessity of
   ACME-DNS (but you gain wildcard certs as a bonus ability).
 * Certificates are installed as individual `.cert`, `.key`, `.pem`
   files, so they may be easily shared with other services, not just
   Traefik.
 * Acme.sh is a focussed ACME client and offers more control than the
   builtin Traefik one.
 * A builtin restart hook is required to restart Traefik after
   certificates are issued/renewed. (In theory this should not be
   necessary, because the Traefik file provider has an optional watch
   parameter that should reload its configuration when modified,
   however it seems to ignore the TLS certificate list in doing so, so
   this seems broken to me.)
 * You may self-host [acme-dns](../acme-dns) with d.rymcg.tech, but
   you must do so on a different machine. 
 * If you don't want to self-host [acme-dns](../acme-dns), you may use
   the free public ACME-DNS service at
   [http://auth.acme-dns.io/](http://auth.acme-dns.io/), but this is
   less reliable/trustworthy than using your own instance.

In the `make config` menu, choose:

 * `TLS certificates and authorities`
   * `Configure ACME`
     * Choose `Acme.sh + ACME-DNS`
     * Choose `Let's Encrypt (production)` (or something else if you know what you're doing.)
     * Enter the base URL of the ACME-DNS server you chose (e.g. `https://auth.acme-dns.io`)
     * Choose the DNS Resolver, Cert period, etc. (just choose the defaults)

When done configuring, it will automatically register an account with
the ACME-DNS provider you chose (if you need to run this part again,
you may run `make acme-sh-register` idempotently). It will print the
CNAME record that you must set on your root domain's DNS server. This
is to delegate the ACME authority of the sub-domains to your ACME-DNS
server. 

You must manually setup the CNAME records exactly as printed, *before*
installing Traefik. Whenever you create new certificates (see
[Certificate Manager](#certificate-manager)), you must run the
`(Re-)Register acme-dns CNAME records for all certs.` option (or `make
acme-sh-register`).

### Traefik builtin ACME client (legacy)

Traefik also has its own ACME client (based on
[LEGO](https://go-acme.github.io/lego/)). This is easier to configure,
and it works directly with Let's Encrypt (or Step-CA), along with your
*root* domain's DNS server instead.

This has a number of benefits and drawbacks:

 * Certificates are stored in a Traefik's certificate store, not as
   individual .pem files. (Note you could still use
   [ldez/traefik-certs-dumper/](https://github.com/ldez/traefik-certs-dumper/)
   if you wanted to)
 * Supports TLS-ALPN challenge type.
 * For DNS-01 challenges, it requires that you store API credentials
   for your *root* domain's DNS server, which may be a security issue
   if the the credentials are not specifically scoped to the
   permissions to update a single domain name TXT record (DigitalOcean
   scoped permissions are not specific enought to address this, but I
   think you could still achive this with AWS IAM).
 * Since Traefik is requesting the certificates, Traefik does not need
   to be restarted.
 * There is no DNS delegation, so no extra CNAME records need to be
   created.

In the `make config` menu, choose:

 * `TLS certificates and authorities`
   * `Configure ACME`
     * Choose `Let's Encrypt`
     * Choose `Production`
     * Choose `TLS-ALPN-01` for most public servers (otherwise choose
       `DNS-01` for advanced use-cases, but this also requires storing
       the security sensitive API key of your DNS provider.)

## Certificate Manager

By convention, d.rymcg.tech sub-projects do not provision, nor even
request, their own TLS certificates. All TLS certificates are to be
explicitly managed by the Traefik [static configuration
template](https://github.com/EnigmaCurry/d.rymcg.tech/blob/e6a4d0285f04d6d7f07fb9a5ec403ba421229747/traefik/config/traefik.yml#L80-L87),
directly on the entrypoint (and not on the route!). Therefore, you
must configure all of the certificate domain names via `make config`,
and then *reinstall Traefik*, before any new certificates may be used.
(ACME may be used to automatically issue and renew these certificates,
once defined.) Applications provided by d.rymcg.tech will never
specify their own Traefik cert resolvers, they should rely upon one of
the staticly defined certificate resolvers instead. Applications that
provide routes that do not have a matching certificate, will
automatically use the `TRAEFIK DEFAULT` certificate, which is
self-signed, and not trusted in browsers.

In the `make config` menu, choose:

 * `TLS certificates and authorities`
   * `Configure TLS certificates`
     * Choose `Create a new certificate.`
     * Enter the fully qualified doman name (CN) of your application.
       (eg. `whoami.example.com`)
     * Enter alternative domain names (SANS) to also include on the
       same certificate.
     * Enter blank to finish entering domain names.

You can create several certificates, and each certificate may list
several domains (CN+SANS). The final list of all your certificate
domains+SANS is saved back into your `.env_${DOCKER_CONTEXT}_default`
file in the `TRAEFIK_ACME_CERT_DOMAINS` variable as a JSON nested
list. When you run `make install` this is pushed into the [static
configuration
template](https://github.com/EnigmaCurry/d.rymcg.tech/blob/e6a4d0285f04d6d7f07fb9a5ec403ba421229747/traefik/config/traefik.yml#L80-L87).

 * If you are using acme-sh (acme-dns) you must run `(Re-)Register
   acme-dns CNAME records for all certs.` and follow the directions to
   create CNAME records on your DNS host.

Make sure you reinstall Traefik after making configuration changes.

## Traefik config templating

All of the Traefik [static
configuration](https://doc.traefik.io/traefik/getting-started/configuration-overview/#the-static-configuration)
is created from a [template](config/traefik.yml) (`traefik.yml`) each
time the container is started with `make install`. This template file
is rendered with the [ytt](https://carvel.dev/ytt/) tool. It takes the
environment variables from `.env_DOCKER_CONTEXT` and puts them into
the rendered config file inside the container
(`/data/config/traefik.yml`).

The Traefik [dynamic
configuration](https://doc.traefik.io/traefik/getting-started/configuration-overview/#the-dynamic-configuration) comes from three places:

 * The ytt templates placed in the [config-templates](config/config-templates) directory are
   loaded by the Traefik [file
   provider](https://doc.traefik.io/traefik/providers/file/).
 * The templates placed in the
   [context-templates](config/context-templates) directory are ignored
   by the git repository, and serve as a local-only config store, they
   are loaded on a per-Docker-Context basis from sub-directories named
   after each context. This lets you customize a particular Traefik
   instance.
 * The [Docker
   provider](https://doc.traefik.io/traefik/providers/docker/) loads
   dynamic configuration directly from Docker container labels,
   allowing applications to configure their own routes and middleware.
   
You can turn off the file provider by setting
`TRAEFIK_FILE_PROVIDER=false` and/or turn off the Docker provider by
setting `TRAEFIK_DOCKER_PROVIDER=false`.

You can inspect the live traefik config after the templating has been
applied:

```
# Traefik must be running:
make config-inspect
```

## Dashboard

Traefik includes a dashboard to help visualize your configuration and detect
errors. The dashboard service is not exposed to the internet, so you must tunnel
throuh SSH to your docker server in order to see it. 

The Traefik dashboard is disabled by default! To access the dashboard,
the `dashboard` entrypoint must be enabled via `make config`, before
following the rest of these steps:

In the `make config` menu, choose:
 * `Entrypoints`
   * `Configure stock entrypoints`
     * `dashboard` - Enable the Traefik Dashboard, and set a
       username/password for it.
 * Reinstall Traefik

A Makefile target is setup to easily access the private dashboard through an SSH
tunnel:

```
# Starts the SSH tunnel if its not already running, 
# and automatically opens your browser, 
# prefilling the username/password if its available in passwords.json:
make open
```

You can `make close` later if you want to close the SSH tunnel.

If you don't wish to use the Makefile, you can start the tunnel manually:

```
ssh -N -L 8080:127.0.0.1:8080 ssh.example.com &
```

With the tunnel active, you can view
[https://localhost:8080/dashboard/](https://localhost:8080/dashboard/) in your
web browser to access it. Enter the username/password you configured.

### TUI Dashboard

There is a TUI dashboard to make it easier to view the dashboard
direclty in your workstation terminal

 * Install
   [tt-tui-for-traefik](https://github.com/EnigmaCurry/tt-tui-for-traefik)
   
```
uvx tool install tt-tui-for-traefik
```

 * Run the dashboard
 
```
make dashboard
```

If you chose to save the Traefik dashboard credentials in
`passwords.json`, they will be automatically used to connect to the
dashboard, otherwise you will be prompted to enter your credentials
(not saved).

## Traefik plugins

The Traefik container image is rebuilt each time you run `make
install` (or by choosing `Reinstall Traefik` from the menu). At that
time, Traefik plugins are automatically cloned from a git source
repository, and built into a custom container image.

This configuration has builtin support for the following plugins:

 * [blockpath](https://github.com/traefik/plugin-blockpath) -
   middleware that returns 401 Forbidden. (Enable by setting
   `TRAEFIK_PLUGIN_BLOCKPATH=true`)
   ([whoami](../whoami/docker-compose.yaml) has an example)
 * [geoip2](https://github.com/forestvpn/traefikgeoip2) -
   middleware that adds headers containing geographic location based
   upon IP address. (Enable by setting
   `TRAEFIK_PLUGIN_MAXMIND_GEOIP=true`)
   ([whoami](../whoami/docker-compose.yaml) has an example)
 * [referer](https://github.com/moonlightwatch/referer) -
   middleware that prevents foreign referal URLs.
 * [headauth](https://github.com/poloyacero/headauth) used for
   implementing OAuth2 sentry authorization, which filters allowed
   users by groups, and it forwards the authenticated user in the
   `X-Forwarded-User` header field to your app.
 * [certauthz](github.com/famedly/traefik-certauthz) used for
   implementing mTLS sentry authorization based on a filter of allowed
   client certificates.
 * [mtlsheader](github.com/pnxs/traefik-plugin-mtls-header) also used
   for implementing mTLS sentry authentication, it forwards the
   client's authenticated name (CN) as the `X-Client-CN` header field
   to your app.
 
You can add third party plugins by modifying the
[Dockerfile](Dockerfile), and follow the example of blockpath. You
also need to [add your plugin to the traefik static
configuration](https://github.com/EnigmaCurry/d.rymcg.tech/blob/291beafcbe8aa83860619d3a18336efce7c67c0a/traefik/config/traefik.yml#L15-L22).

Find more plugins in the [Traefik Plugin
Catalog](https://plugins.traefik.io/plugins). Note that plugins do not
need to be compiled, but the source code must be added to the docker
container image at build time. Plugin source code is interpreted by
[yaegi](https://github.com/traefik/yaegi) at run time.

Turn off all plugins by setting `TRAEFIK_PLUGINS=false`.

## Install the whoami container

Consider installing the [whoami](../whoami) container, which will
demonstrate a valid TLS certificate, and an example of routing Traefik
to web servers running in project containers.

## OAuth2 authentication

If you install the [traefik-forward-auth](../traefik-forward-auth)
service, you can enable OAuth2 authentication to your
[forgejo](../forgejo) identity provider (or any external OAuth2 provider).

It is important to understand the difference between authentication
and authorization:

 * authentication identifies who a user *is*. (This is what
     traefik-forward-auth does for you, sitting in front of your app.)
 * authorization is a process that determines what a user should be
   *allowed to do* (This is what every application should do for
   itself, or another middleware described below).

To summarize: traefik-forward-auth, by itself, only cares about
identity, not about permissions.

Permissions (authorization) are to be implemented in the app itself.
Traefik-Forward-Auth operates by setting a trusted header
`X-Forwarded-User` that contains the authenticated users email
address. The application receives this header on every request coming
from the proxy. It should trust this header to be a real authenticated
user for the session, and it only needs to decide what that user is
allowed to do (ie. the app should define a map of email address to
permissions that it enforces per request; the app database only needs
to store user registrations, and their permission roles, but doesn't
need to store any user passwords.).

However, many applications do not support this style of delegated
authentication by trusted header. To add authorization to an
unsupported application, you may use the provided [header
authorization
middleware](https://github.com/enigmacurry/traefik-header-authorization),
and it can be configured simply by running this make target:

```
# Configure the header authorization middleware:
make sentry
```

This will configure the `TRAEFIK_HEADER_AUTHORIZATION_GROUPS`
environment variable in your .env file (which is a serialized JSON map
of groups and allowed usernames). Email addresses must match those of
accounts on your Forgejo instance. For example, if you have accounts on
your Forgejo instance for alice@example.com and bob@demo.com, and you
only want Alice to be able to access this app, only enter
`alice@example.com`. Remember to re-install traefik after making any
changes to your authorization groups or permitted email addresses.

Each app must apply the middleware to filter users based on the group
the middleware is designed for. Once you run `make sentry` and configure
authorization groups in the `traefik` folder, when you run `make config` for
that app and elect to configure Oauth2 authentication, you will be asked to
assign one of those groups to your app.

While this extra middleware can get you "in the door" of any app, its
still ultimately up to the app as to what you can do when you get
there, so if the app doesn't understand the `X-Forwarded-User` header,
you may also need to login through the app interface itself, after
having already logged in through Forgejo.

## Step CA (self-hosted ACME certificate provisioner)

Creating TLS certificates with [Step-CA](../step-ca) is a similar
experience as with Let's Encrypt, because both services use a common
API (ACME), to facilitate signing requests, and renewals, of X.509
certificates. The differences are: all of the certitficates signed by
Step-CA will be "self-signed" (and untrusted by browsers by default),
however, all of the crypto infrastructure is self-hosted inside of
*your* domain. Step-CA also brings the additional feature of
[mTLS](https://smallstep.com/hello-mtls/doc/server/traefik), for
mutual authentication of both client and server (afaik Let's Encrypt
doesn't issue client certs, so this is a bonus with Step-CA).

If you want to use self-signed certificates with Step-CA, there are
a few possible changes to your configs you'll need to consider:

 1) Add the root CA certificate to the Traefik container's trust store.
 2) Enable ACME in your Step-CA instance.
 3) Enable ACME in your Traefik config.
 
If you are creating certificates manually (via [step-ca](../step-ca)
project, `make cert`), then you can skip enabling ACME, which
is only needed if you want a fully automatic Let's Encrypt-like
experience instead.

### Add the Step CA root certificate to the Traefik trust store

Set the following variables in your Traefik `.env_{CONTEXT}` file:

 * `TRAEFIK_STEP_CA_ENABLED=true`
 * `TRAEFIK_STEP_CA_ENDPOINT=https://ca.example.com` (set this to your Step-CA root URL)
 * `TRAEFIK_STEP_CA_FINGERPRINT=xxxxxxxxxxxxxxxxxxxx` (set this to
   your Step-CA fingerprint, eg. use `make inspect-fingerprint` in the
   [step-ca](../step-ca) project to find it.)
 * `TRAFEIK_STEP_CA_ZERO_CERTS=true` (set this true if you want to delete all other CA certs.)

Make sure to reinstall Traefik (`make install`) for these settings to
take effect. The image will be rebuilt, baking in your root CA
certificate. The [Dockerfile](Dockerfile) runs `step-cli`, it
retrieves the CA cert chain from your Step-CA endpoint, verifies the
fingerprint, and then writes the CA cert permanently into the Traefik
system's trust store (ie. container image layer).

You can test that the certificate is trusted and valid, using the
`curl` command from inside of the trafeik container shell:

```
# Enter the traefik container shell:
make shell
```

```
# Inside the container, test the certificate trust with curl:
# Use the full URL to your Step-CA server:
curl https://ca.example.com
```

If it works, you should see `404 error not found`, which is good (the
root URL `/` is actually a 404). What you should *NOT* see is an error
message about the certificate being invalid:

```
## Example error you should NOT see:
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```

If the certificates have been installed correctly, you shouldn't see
the example error above. All programs running in the container,
including `curl`, and Traefik itself, will now trust any certificate
signed by your Step-CA instance.

### Enable Step-CA ACME (optional)

To automate the creation and signing of TLS certificates, you will
want to enable ACME.

```
## In step-ca project directory:
make enable-acme
```

Next, edit the Traefik `.env_{CONTEXT}` file to change the production cert resolver URL:

 * `TRAEFIK_ACME_CERT_RESOLVER=production` (make sure this says
   `production`)
 * `TRAEFIK_ACME_CERT_RESOLVER_PRODUCTION=https://ca.example.com/acme/acme/directory`
   (point this to your Step-CA ACME endpoint)

The production cert resolver should now be pointing to your Step-CA
URL, with the extra path `/acme/acme/directory` added on the end. Do
not change the name to anything other than `production`; only change
the URL. Reinstall Traefik (`make install`).

You can also setup a `staging` endpoint if you really want to (eg. set
`TRAEFIK_ACME_CERT_RESOLVER_STAGING=https://staging.ca.example.com/acme/acme/directory`
and `TRAEFIK_ACME_CERT_RESOLVER=staging`). However, these are your
only two options, defined in [traefik's certificatesResolvers
list](https://github.com/EnigmaCurry/d.rymcg.tech/blob/de000cb8b5fe1686925c3f167221ed74372860ba/traefik/config/traefik.yml#L71-L103).
Use `production` or `staging`.

## Wireguard VPN

> [!NOTE]
> This section describes how to make Traefik act as a **Layer 7**
> (TLS) VPN, typical of company wide intranets. If you want a **Layer
> 4** (TCP/UDP) VPN, typical of consumer privacy shields, check out the
> separate [wireguard](../wireguard#readme) config].

This config uses the following environment variables to configure
wireguard, and the default value is shown:

 * `TRAEFIK_VPN_ENABLED=false` - If `true`, enable the wireguard *server* sidecar.
 * `TRAEFIK_VPN_CLIENT_ENABLED=false` - If `true`, enable the wireguard *client* sidecar.
 * `TRAEFIK_NETWORK_MODE=host` - Set the network mode of the
   container, to `host`, `service:wireguard`, or
   `service:wireguard-client`.
 * `TRAEFIK_*_ENTRYPOINT_HOST=0.0.0.0` - Each entrypoint configures
   the IP address it should listen on, which can make the entrypoints
   public (`0.0.0.0`) or private (`10.13.16.2`) accordingly.

The easiest way to configure any of these configurations is to run the
`make config` script. 

 * Choose the `Configure wireguard VPN` menu option.

You may want to have several Traefik instances all on the same VPN.
You will need to designate *one* of them to be the wireguard "server"
(ie. the most public one), and the rest of them are to be wireguard
"clients".

### Retrieve client credentials

Once you've started a wireguard server instance, you will need to copy
the credentials to your clients. There are two ways to retrieve the
client credentials from the server:

   * `make show-wireguard-peers` - output text config of each peer.
   * `make show-wireguard-peers-qr` - QR encoded output to scan with
     android wireguard app.

### Reset wireguard server

Wireguard runs inside the server host OS kernel. If you reconfigure
the wireguard server, even if you delete the wireguard container, you
may need to clean up the existing server connection:

```
## Same as `wg-quick down wg0` on the server:
make wireguard-reset
```

## Environment Variables

Here is a description of every single environment variable in the
Traefik [.env](.env-dist) file :

| Variable name                              | Description                                                                      | Examples                                                 |
|--------------------------------------------|----------------------------------------------------------------------------------|----------------------------------------------------------|
| (various LEGO DNS variables)               | All of your tokens for DNS provider                                              | `DO_AUTH_TOKEN`                                          |
| `DOCKER_COMPOSE_PROFILES`                  | List of docker-compose profiles to enable                                        | `default`,`wireguard`,`wireguard-client`                 |
| `TRAEFIK_ACCESS_LOGS_ENABLED`              | (bool) enable the Traefik access logs                                            | `true`,`false`                                           |
| `TRAEFIK_ACCESS_LOGS_PATH`                 | The path to the access logs inside the volume                                    | `/data/access.log`                                       |
| `TRAEFIK_ACME_CA_EMAIL`                    | Your email to send to Lets Encrypt                                               | `you@example.com` (can be blank)                         |
| `TRAEFIK_ACME_CERT_DOMAINS`                | The JSON list of all certificate domans                                          | Use `make certs` to manage                               |
| `TRAEFIK_ACME_CERT_RESOLVER_PRODUCTION`    | ACME production endpoint API URL                                                 | `https://acme-v02.api.letsencrypt.org/directory`         |
| `TRAEFIK_ACME_CERT_RESOLVER_STAGING`       | ACME staging endpoint API URL                                                    | `https://acme-staging-v02.api.letsencrypt.org/directory` |
| `TRAEFIK_ACME_CERT_RESOLVER`               | Lets Encrypt API environment                                                     | `production`,`staging`                                   |
| `TRAEFIK_ACME_CERT_RESOLVER`               | Lets Encrypt API environment                                                     | `production`,`staging`                                   |
| `TRAEFIK_ACME_CHALLENGE`                   | The ACME challenge type                                                          | `tls`,`dns`                                              |
| `TRAEFIK_ACME_DNS_PROVIDER`                | The LEGO DNS provider name                                                       | `digitalocean`                                           |
| `TRAEFIK_ACME_DNS_VARNAME_1`               | The first LEGO DNS variable name                                                 | `DO_AUTH_TOKEN`                                          |
| `TRAEFIK_ACME_DNS_VARNAME_2`               | The second LEGO DNS variable name                                                | leave blank if there are no more                         |
| `TRAEFIK_ACME_DNS_VARNAME_3`               | The thrid LEGO DNS variable name                                                 | leave blank if there are no more                         |
| `TRAEFIK_ACME_DNS_VARNAME_4`               | The fourth LEGO DNS variable name                                                | leave blank if there are no more                         |
| `TRAEFIK_ACME_DNS_VARNAME_5`               | The fifth LEGO DNS variable name                                                 | leave blank if there are no more                         |
| `TRAEFIK_ACME_ENABLED`                     | (bool) Enable ACME TLS certificate resolver                                      | `true`,`false`                                           |
| `TRAEFIK_ACME_SH_ACMEDNS_ACCOUNT_JSON`     | The path to store the acmedns account json                                       | `/acme.sh/acmedns-account.json`                          |
| `TRAEFIK_ACME_SH_ACMEDNS_ALLOW_FROM`       | The list of CIDR allowed to update the records (optional)                        |                                                          |
| `TRAEFIK_ACME_SH_ACMEDNS_PASSWORD`         | The ACME DNS password (only if the account is pre-generated)                     |                                                          |
| `TRAEFIK_ACME_SH_ACMEDNS_SUBDOMAIN`        | The ACME DNS challenge domain (only if the account is pre-generated)             |                                                          |
| `TRAEFIK_ACME_SH_ACMEDNS_USERNAME`         | The ACME DNS username (only if the account is pre-generated)                     |                                                          |
| `TRAEFIK_ACME_SH_ACME_CA`                  | The URL to the ACME service (e.g., Step-CA or Lets Encrypt)                      | `ca.example.com`                                         |
| `TRAEFIK_ACME_SH_ACME_DIRECTORY`           | The path of the ACME service                                                     | `/acme/acme/directory`                                   |
| `TRAEFIK_ACME_SH_ACME_DNS_BASE_URL`        | The URL to the ACME-DNS service                                                  | `https://auth.acme-dns.io`                               |
| `TRAEFIK_ACME_SH_CERT_PERIOD_HOURS`        | How long the certificates should be in hours (Step-CA only)                      | `1440`                                                   |
| `TRAEFIK_ACME_SH_CRON_SCHEDULE`            | The cron schedule for renewing certificates                                      | `0 * * * *`                                              |
| `TRAEFIK_ACME_SH_DNS_RESOLVER`             | The DNS resolver to use when checking records                                    | `1.1.1.1`                                                |
| `TRAEFIK_ACME_SH_ENABLED`                  | (bool) enable acme.sh                                                            | `false`                                                  |
| `TRAEFIK_ACME_SH_GIT_REPO`                 | The git repo to build acme.sh from                                               | `https://github.com/acmesh-official/acme.sh`             |
| `TRAEFIK_ACME_SH_GIT_TAG`                  | The release tag of acme.sh to build                                              |                                                          |
| `TRAEFIK_ACME_SH_TRUST_SYSTEM_STORE`       | (bool) Whether or not to trust the system TLS store                              | `true`, `false`                                          |
| `TRAEFIK_CONFIG_VERBOSE`                   | (bool) Print config to logs                                                      | `false`,`true`                                           |
| `TRAEFIK_CONFIG_YTT_VERSION`               | YTT tool version                                                                 | `v0.43.0`                                                |
| `TRAEFIK_DASHBOARD_ENTRYPOINT_ENABLED`     | (bool) Enable the dashboard entrypoint                                           | `true`, `false`                                          |
| `TRAEFIK_DASHBOARD_ENTRYPOINT_HOST`        | The IP address to bind to                                                        | `127.0.0.1` (host networking) `0.0.0.0` (VPN)            |
| `TRAEFIK_DASHBOARD_ENTRYPOINT_PORT`        | The TCP port for the daashboard                                                  | `8080`                                                   |
| `TRAEFIK_DASHBOARD_HTTP_AUTH`              | The htpasswd encoded password for the dashboard                                  | `$$apr1$$125jLjJS$$9WiXscLMURiMbC0meZXMv1`               |
| `TRAEFIK_DOCKER_PROVIDER_CONSTRAINTS`      | [Constraints](https://doc.traefik.io/traefik/providers/docker/#constraints) rule | None                                                     |
| `TRAEFIK_DOCKER_PROVIDER`                  | (bool) Enable the Traefik docker provider                                        | `true`,`false`                                           |
| `TRAEFIK_FILE_PROVIDER_WATCH`              | (bool) Enable automatic file reloading                                           | `false`,`true`                                           |
| `TRAEFIK_FILE_PROVIDER`                    | (bool) Enable the Traefik file provider                                          | `true`,`false`                                           |
| `TRAEFIK_GEOIPUPDATE_ACCOUNT_ID`           | MaxMind account id for GeoIP database download                                   |                                                          |
| `TRAEFIK_GEOIPUPDATE_EDITION_IDS`          | The list of GeoIP databases to download                                          | `GeoLite2-ASN GeoLite2-City GeoLite2-Country`            |
| `TRAEFIK_GEOIPUPDATE_LICENSE_KEY`          | MaxMind license key for GeoIP database download                                  |                                                          |
| `TRAEFIK_HEADER_AUTHORIZATION_GROUPS`      | JSON list of user groups for OAuth2 authorization                                | `{"admin":["root@localhost"]}`                           |
| `TRAEFIK_IMAGE`                            | The Traefik docker image                                                         | `traefik:v2.9`                                           |
| `TRAEFIK_LOG_LEVEL`                        | Traefik log level                                                                | `warn`,`error`,`info`, `debug`                           |
| `TRAEFIK_MPD_ENTRYPOINT_ENABLED`           | (bool) Enable mpd (unencrypted) entrypoint                                       |                                                          |
| `TRAEFIK_MPD_ENTRYPOINT_HOST`              | Host ip address to bind mpd entrypoint                                           | `0.0.0.0`                                                |
| `TRAEFIK_MPD_ENTRYPOINT_PORT`              | Host TCP port to bind mpd entrypoint                                             | `6600`                                                   |
| `TRAEFIK_NETWORK_MODE`                     | Bind Traefik to host or serivce container networking                             | `host`,`wireguard`,`wireguard-client`                    |
| `TRAEFIK_PLUGINS`                          | (bool) Enable Traefik plugins                                                    | `true`,`false`                                           |
| `TRAEFIK_PLUGIN_BLOCKPATH`                 | (bool) Enable BlockPath plugin                                                   | `true`,`false`                                           |
| `TRAEFIK_PLUGIN_MAXMIND_GEOIP`             | (bool) Enable GeoIP plugin                                                       | `false`, `true`                                          |
| `TRAEFIK_REDIS_ENTRYPOINT_ENABLED`         | (bool) Enable redis  entrypoint                                                  |                                                          |
| `TRAEFIK_REDIS_ENTRYPOINT_HOST`            | Host ip address to bind redis entrypoint                                         | `0.0.0.0`                                                |
| `TRAEFIK_REDIS_ENTRYPOINT_PORT`            | Host TCP port to bind redis entrypoint                                           | `1704`                                                   |
| `TRAEFIK_ROOT_DOMAIN`                      | The default root domain of every service                                         | `d.rymcg.tech`                                           |
| `TRAEFIK_SEND_ANONYMOUS_USAGE`             | (bool) Whether to send usage data to Traefik Labs                                | `false`, `true`                                          |
| `TRAEFIK_SNAPCAST_ENTRYPOINT_ENABLED`      | (bool) Enable snapcast (unencrypted) entrypoint                                  |                                                          |
| `TRAEFIK_SNAPCAST_ENTRYPOINT_HOST`         | Host ip address to bind snapcast entrypoint                                      | `0.0.0.0`                                                |
| `TRAEFIK_SNAPCAST_ENTRYPOINT_PORT`         | Host TCP port to bind snapcast entrypoint                                        | `1704`                                                   |
| `TRAEFIK_SSH_ENTRYPOINT_ENABLED`           | (bool) Enable ssh (port 2222) entrypoint                                         | `true`,`false`                                           |
| `TRAEFIK_SSH_ENTRYPOINT_HOST`              | Host ip address to bind ssh entrypoint                                           | `0.0.0.0`                                                |
| `TRAEFIK_SSH_ENTRYPOINT_PORT`              | Host TCP port to bind ssh entrypoint                                             | `2222`                                                   |
| `TRAEFIK_STEP_CA_ENABLED`                  | (bool) Enable Step CA trusted CA                                                 | `true`,`false`                                           |
| `TRAEFIK_STEP_CA_ENDPOINT`                 | Step-CA server URL                                                               | `https://ca.example.com`                                 |
| `TRAEFIK_STEP_CA_FINGERPRINT`              | Step-CA root CA fingerprint                                                      | `xxxxxxxxxxxx`                                           |
| `TRAEFIK_STEP_CA_ZERO_CERTS`               | (bool) Remove all other CA certs from the system                                 | `false`                                                  |
| `TRAEFIK_VPN_ADDRESS`                      | Private VPN IP address of Traefik server                                         | `10.13.16.1`                                             |
| `TRAEFIK_VPN_ALLOWED_IPS`                  | Which IP subnets are routable by the VPN                                         | `10.13.16.0/24`, `0.0.0.0` (all traffic)                 |
| `TRAEFIK_VPN_CLIENT_ENABLED`               | (bool)  Enable the VPN client                                                    | `false`,`true`                                           |
| `TRAEFIK_VPN_CLIENT_INTERFACE_ADDRESS`     | The VPN client private IP address                                                | `10.13.16.2`                                             |
| `TRAEFIK_VPN_CLIENT_INTERFACE_LISTEN_PORT` | The VPN client listen port                                                       | `51820`                                                  |
| `TRAEFIK_VPN_CLIENT_INTERFACE_PEER_DNS`    | The VPN client peer DNS                                                          | `10.13.16.1`                                             |
| `TRAEFIK_VPN_CLIENT_INTERFACE_PRIVATE_KEY` | The VPN client private key                                                       | `4xxxxxxx=`                                              |
| `TRAEFIK_VPN_CLIENT_PEER_ALLOWED_IPS`      | The VPN client allowed routable IP addresses                                     | `10.13.16.1/32`                                          |
| `TRAEFIK_VPN_CLIENT_PEER_ENDPOINT`         | The VPN server public endpoint                                                   | `vpn.example.com:51820`                                  |
| `TRAEFIK_VPN_CLIENT_PEER_PRESHARED_KEY`    | The VPN client preshared key                                                     | `6xxxxxxx=`                                              |
| `TRAEFIK_VPN_CLIENT_PEER_PUBLIC_KEY`       | The VPN client public key                                                        | `5xxxxxxx=`                                              |
| `TRAEFIK_VPN_CLIENT_PEER_SERVICES`         | The list of VPN services to forward                                              | `whoami,piwigo,freshrss`                                 |
| `TRAEFIK_VPN_ENABLED`                      | (bool) enable VPN server                                                         | `false`,`true`                                           |
| `TRAEFIK_VPN_HOST`                         | Public hostname of VPN server                                                    | `vpn.example.com`                                        |
| `TRAEFIK_VPN_PEERS`                        | The number or list of clients to create                                          | `client1,client2`, `1`                                   |
| `TRAEFIK_VPN_PEER_DNS`                     | The DNS server that clients are advertised to use                                | `auto` (uses host), `1.1.1.1`                            |
| `TRAEFIK_VPN_PORT`                         | The TCP port to bind the VPN server to                                           | `51820`                                                  |
| `TRAEFIK_VPN_SUBNET`                       | The first .0 IP address of the private VPN subnet                                | `10.13.16.0`                                             |
| `TRAEFIK_WEBSECURE_ENTRYPOINT_ENABLED`     | (bool) Enable websecure (port 443) entrypoint                                    | `true`,`false`                                           |
| `TRAEFIK_WEBSECURE_ENTRYPOINT_HOST`        | Host ip address to bind websecure entrypoint                                     | `0.0.0.0`                                                |
| `TRAEFIK_WEBSECURE_ENTRYPOINT_PORT`        | Host TCP port to bind websecure entrypoint                                       | `443`                                                    |
| `TRAEFIK_WEB_ENTRYPOINT_ENABLED`           | (bool) Enable web (port 80) entrypoint                                           | `true`,`false`                                           |
| `TRAEFIK_WEB_ENTRYPOINT_HOST`              | Host ip address to bind web entrypoint                                           | `0.0.0.0`                                                |
| `TRAEFIK_WEB_ENTRYPOINT_PORT`              | Host TCP port to bind web entrypoint                                             | `80`                                                     |
| `TRAEFIK_WEB_PLAIN_ENTRYPOINT_ENABLED`     | (bool) Enable web_plain (port 8000) entrypoint                                   | `true`,`false`                                           |
| `TRAEFIK_WEB_PLAIN_ENTRYPOINT_HOST`        | Host ip address to bind web_plain entrypoint                                     | `0.0.0.0`                                                |
| `TRAEFIK_WEB_PLAIN_ENTRYPOINT_PORT`        | Host TCP port to bind web_plain entrypoint                                       | `8000`                                                   |

## Implementation

 * By default, Traefik binds to the host network, which gives it the
   ability to directly access any container, and not need to attach to
   any specific Docker networks. Sharing the host network also means
   there is no list of ports to publish for Traefik, because the host
   network is allowed to bind to any port. (*It is the responsibility
   of your external firewall to block access to unintended ports*).
 * TLS certificates are explicitly defined using the `make certs`
   tool, and automatically issued/renewed by ACME. However, Traefik
   [certresolvers](https://doc.traefik.io/traefik/routing/routers/#certresolver)
   are ***not*** being used on the router level, but are applied to
   the entire entrypoint (`websecure`) as a whole. You only need to
   configure the router rules with a `Host` that matches one of your
   certificates (otherwise it may use an untrusted temporary
   self-signed certificate).
 * The Traefik static configuration is no longer defined in
   `docker-compose.yaml`, but it is templated inside of
   [traefik.yml](config/traefik.yml) which is rendered automatically
   via the [ytt](https://carvel.dev/ytt/) tool when you run `make
   install`. (This happens inside the [config](config) container, so
   you don't need to install ytt on your workstation.)
 * Traefik does not run as root, but under a dedicated system (host)
   user account named `traefik` (this user is automatically created on
   the host, the first time you run `make config`). The `traefik` user
   is added to the `docker` group, so that it can access the docker
   socket. This is still very much considred a privileged account, as
   it can read all the environment variables of all your containers,
   and can escalate itself to root level access, through the use of
   the docker API.)
 * Authentication is provided on a per app basis with HTTP Basic
   Authentication, OAuth2, or mTLS, and includes senty authorization
   middleware, to prevent unauthorized access. 
