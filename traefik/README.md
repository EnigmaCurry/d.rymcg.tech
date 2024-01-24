# Traefik

[Traefik](https://github.com/traefik/traefik) is a modern TLS / HTTP /
TCP / UDP reverse proxy and load balancer. Traefik is the front-most
gateway for (almost) all of the projects hosted by d.rymcg.tech, and
should be the first thing you install in your deployment.

## Implementation

 * By default Traefik binds to the host network, which gives Traefik
   the ability to directly access any container network, and not
   needing to attach every container to a specific proxy network.
   Sharing the host network also means there is no list of ports to
   maintain for Traefik, because Traefik can bind to any port on the
   host. (*It is the responsibility of your external firewall to block
   unintended public access*).
 * Alternatively, Traefik can bind to the network of a wireguard VPN;
   in the form of either a server configuration (serving to other VPN
   clients), or as a client reverse proxy (forwarding private services
   to public non-VPN clients). In this mode, Traefik will bind
   directly to the wireguard container network (`network_mode:
   service:wireguard` or `network_mode: service:wireguard-client` and
   then the wireguard server itself will bind to the host port `51820`
   by default, for authorized clients to connect to.)
 * TLS certificates are automatically managed by ACME, but the
   certificate domains are manually defined using the `make certs`
   tool. Traefik
   [certresolvers](https://doc.traefik.io/traefik/routing/routers/#certresolver)
   are ***not*** being used on the router level, but instead apply to
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
   Authentication or OAuth2, with a general group based authorization
   middleware adaptable to secure any application.

## Config

Open your terminal, and change to this directory (`traefik`).

Traefik needs limited, but privileged, access to your Docker host.
Rather than run as root, you must create a new `traefik` user account
for it to use instead. You can do this with the Makefile target:

```
make traefik-user

## You can do this manually if you prefer (on the Docker Host:)
# adduser --disabled-login --disabled-password --gecos GECOS traefik
# gpasswd -a traefik docker
```

Run the interactive configuration wizard:

```
make config
```

Follow the prompts and answer the questions. You will configure the
ACME certificate resolver, the Traefik dashboard access credentials,
Traefik plugins, and optionally the VPN server or client.

Next, you can configure the TLS certificates. Run:

```
make certs
```

(Follow the [certificate manager](#certificate-manager) section for a
detailed example of creating certificates and then come back here.)

```
# Optional: Make security groups for header authorization middleware:
make sentry
```

(`make sentry` is only required if you want to configure Oauth2
authentication - follow the [Oauth2
authentication](#oauth2-authentication) section for instructions how
to create authorization groups, or you can do that anytime later.)

Double check that the config has now been created in your
`.env_${DOCKER_CONTEXT}_default` file and make any final edits (there are a
few settings that are not covered by the wizard, so you may want to
set them by hand). Also note that you can re-run `make config`
anytime, and it will remember your choices from the last time and make
those the default answers.

Once you're happy with the config, install Traefik:

```
make install
```

Check the Traefik logs for any errors:

```
make logs
```

Open the dashboard:

```
make open
```

Now go install the [whoami](../whoami) service, watch the traefik log
for any errors, test that the service works, and see that it shows up
in the dashboard.

## Certificate manager

Most sub-projects of d.rymcg.tech *do not* specify any certificate
resolver via the docker provider labels on the container/router.
Instead, certificates are explicitly managed by the Traefik [static
configuration
template](https://github.com/EnigmaCurry/d.rymcg.tech/blob/e6a4d0285f04d6d7f07fb9a5ec403ba421229747/traefik/config/traefik.yml#L80-L87)
directly on the entrypoint. Therefore you must configure the
certificate domains, *and reinstall Traefik*, before these
certificates may be used.

`make certs` is an interactive tool that configures the
`TRAEFIK_ACME_CERT_DOMAINS` variable in the Traefik
`.env_${DOCKER_CONTEXT}_default` file, which is stored as a JSON list of
domains. This variable feeds the static configuration template, which
builds the configuration on each startup of the Traefik container.

```
$ make certs
Certificate manager:
 * Type `q` or `quit` to quit the certificate manager.
 * Type `l` or `list` to list certificate domains.
 * Type `d` or `delete` to delete an existing certificate domain.
 * Type `c` or `n` or `new` to create a new certificate domain.
 * Type `?` or `help` to see this help message again.
```

For example, suppose you are deploying the [whoami](../whoami)
service, and you want a TLS certificate for that deployment.

Press `c` to create a new certificate domain.

```
Configure the domains for the new certificate:
Enter the main domain for this certificate (eg. `d.rymcg.tech` or `*.d.rymcg.tech`):
```

At this prompt, enter the main domain, the same way as you chose for
`WHOAMI_TRAEFIK_HOST` in the whoami .env file, eg:
`whoami.d.example.com`. If you chose to use the DNS challenge type,
this can be a wildcard domain instead, eg `*.d.example.com`.

```
Enter a secondary domain (enter blank to skip)
```

At the second prompt here, you can enter additional domains or
wildcards to be listed on the same certificate (SANS; Subject
Alternative Names). For the TLS challenge, wildcards are not allowed,
so you must enter all the domains you want to have explicitly as SANS,
eg. `whoami2.d.example.com`, `whoami3.d.example.com`, etc. (enter each
domain separately, then press Enter on a blank line to finish.)

You can create several certificate domains, and each one can have
several SANS domains. The final list of all your certificate
domains+SANS is saved back into your `.env_${DOCKER_CONTEXT}_default`
file in the `TRAEFIK_ACME_CERT_DOMAINS` variable as a JSON nested
list. When you run `make install` this is pushed into the [static
configuration
template](https://github.com/EnigmaCurry/d.rymcg.tech/blob/e6a4d0285f04d6d7f07fb9a5ec403ba421229747/traefik/config/traefik.yml#L80-L87).

Back at the main menu, type `q` to quit the certificate manager. If
you made changes, it will ask you if you would like to restart
Traefik. If you'd rather wait, thats fine, just run `make install`
when its convenient to restart Traefik.

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
 * The templates placed in the [user-templates](config/user-templates)
   directory are ignored by the git repository and serve as a
   local-only config store, they are loaded identically as the
   `config-templates` directory.
 * The [Docker
   provider](https://doc.traefik.io/traefik/providers/docker/) loads
   dynamic configuration directly from Docker container labels.

You can turn off the file provider by setting
`TRAEFIK_FILE_PROVIDER=false` and/or turn off the Docker provider by
setting `TRAEFIK_DOCKER_PROVIDER=false`.

You can inspect the live traefik config after the templating has been
applied:

```
# Traefik must be running:
make config-inspect
```

## Manual config

If you don't want to run the interactive configuration, you can also
manually copy `.env-dist` to `.env_${DOCKER_CONTEXT}_default`. Follow
the comments inside `.env-dist` for all the available options. Here is
a description of the most relevant options to edit:

 * Choose `TRAEFIK_ACME_CERT_RESOLVER=production` or
   `TRAEFIK_ACME_CERT_RESOLVER=staging` to switch to the appropriate
   Lets Encrpyt API environment. (production for real TLS certs;
   staging for development and non-rate limited access.)
 * `TRAEFIK_ACME_CA_EMAIL` this is your personal/work email address,
   where you will receive notices from Let's Encrypt regarding your
   domains and related certificates or if theres some other problem
   with your account. (optional)
 * `TRAEFIK_ACME_CHALLENGE` set to `tls` or `dns` to use the ACME
   TLS-ALPN-01 or DNS-01 challenge type for requesting new
   certificates.
 * `TRAEFIK_DASHBOARD` if set to `true`, this will turn on the
   [Traefik
   Dashboard](https://doc.traefik.io/traefik/operations/dashboard/).
 * `TRAEFIK_DASHBOARD_HTTP_AUTH` this is the htpasswd encoded username/password to
   access the Traefik API and dashboard. If you ran `make config` this would be
   filled in for you, simply by answering the questions.

Each entrypoint can be configured on or off, as well as the explicit
host IP address and port number:
 * `TRAEFIK_WEB_ENTRYPOINT_ENABLED=true` enables the HTTP entrypoint,
   which is only used for redirecting to the `websecure` entrypoint.
   Use `TRAEFIK_WEB_ENTRYPOINT_HOST` and `TRAEFIK_WEB_ENTRYPOINT_PORT`
   to customize the host (default `0.0.0.0`) and port number (default
   `80`).
 * `TRAEFIK_WEBSECURE_ENTRYPOINT_ENABLED=true` enables the HTTPS
   entrypoint. Use `TRAEFIK_WEBSECURE_ENTRYPOINT_HOST` and
   `TRAEFIK_WEBSECURE_ENTRYPOINT_PORT` to customize the host (default
   `0.0.0.0`) and port number (default `443`).
 * `TRAEFIK_MQTT_ENTRYPOINT_ENABLED=true` enables the MQTT
   entrypoint. Use `TRAEFIK_MQTT_ENTRYPOINT_HOST` and
   `TRAEFIK_MQTT_ENTRYPOINT_PORT` to customize the host (default
   `0.0.0.0`) and port number (default `8883`).
 * `TRAEFIK_SSH_ENTRYPOINT_ENABLED=true` enables the SSH
   entrypoint. Use `TRAEFIK_SSH_ENTRYPOINT_HOST` and
   `TRAEFIK_SSH_ENTRYPOINT_PORT` to customize the host (default
   `0.0.0.0`) and port number (default `2222`).

The DNS-01 challenge type requires some additional environment
variables as specified by the [LEGO
documentation](https://go-acme.github.io/lego/dns). This config
utilizes up to five (5) environment variables to store the *names* of
the appropriate variables for your specific DNS provider:
`TRAEFIK_ACME_DNS_VARNAME_1`, through `TRAEFIK_ACME_DNS_VARNAME_5`.

For example, if you use DigitalOcean's DNS platform, look at the [LEGO
docs for
digitalocean](https://go-acme.github.io/lego/dns/digitalocean/). Here
you find the following info:

 * The provider code is `digitalocean`, so set `TRAEFIK_ACME_DNS_PROVIDER=digitalocean`
 * The required credentials is only one variable, which is specific to
   DigitalOcean: `DO_AUTH_TOKEN` So you set
   `TRAEFIK_ACME_DNS_VARNAME_1=DO_AUTH_TOKEN`.
 * You must also provide the value for this variable. So set
   `DO_AUTH_TOKEN=xxxx-your-actual-digitalocean-token-here-xxxx`.

If your provider requires more than one variable, you set them in the
other slots (up to 5 total), or leave them blank if not needed.

The `TRAEFIK_ACME_CERT_DOMAINS` configures all of the domains for TLS
certificates. It is a JSON list of the form: `[[main_domain1,
[sans_domain1, ...]], ...]`. This list is managed automatically by
running `make certs`.

## Dashboard

Traefik includes a dashboard to help visualize your configuration and detect
errors. The dashboard service is not exposed to the internet, so you must tunnel
throuh SSH to your docker server in order to see it. 

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

## Traefik plugins

Traefik plugins are automatically cloned from a source repository and
built into a custom container image, whenever you run `make install`.

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

You can start the [traefik-forward-auth](../traefik-forward-auth)
service to enable OAuth2 authentication to your [gitea](../gitea)
identity provider (or any external OAuth2 provider).

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
accounts on your Gitea instance. For example, if you have accounts on
your Gitea instance for alice@example.com and bob@demo.com, and you
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
having already logged in through gitea.

## Wireguard VPN

By default Traefik is setup to use the `host` network, which is used
for *public* (internet or LAN) servers. Alternatively, you can start a
wireguard VPN server sidecar container and bind Traefik exclusively to
the private network (`TRAEFIK_VPN_ENABLED=true`). As a third
configuration, you can have a public Traefik server that can reverse
proxy to the VPN to expose private services publicly
(`TRAEFIK_VPN_CLIENT_ENABLED=true`).

The easiest way to configure any of these configurations is to run the
`make config` script. Watch for the following questions to turn the
wireguard services on:

 * `Do you want to run Traefik exclusively inside a VPN?` Say yes to
   this question to configure the wireguard server and bind the
   traefik container to the wireguard container network.
 * `Do you want to run Traefik as a reverse proxy for an external
   VPN?` Say yes to this question to configure the wireguard client
   and bind the Traefik container to the wireguard client container
   network.
 * If you say N to both questions, Traefik will bind to the `host`
   network.

Note: Traefik can only bind to a single network at a time, so you may
choose to configure `TRAEFIK_VPN_ENABLED=true`, **or**
`TRAEFIK_VPN_CLIENT_ENABLED=true`, or neither, *but not both
simultaneously*. To use a client and a server connected to the same
VPN, you should deploy Traefik to two separate docker contexts.

### Retrieve client credentials

There are two ways to retrieve the client credentials from the server,
which you will need to enter into your client:

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

### Wireguard VPN client

[![Traefik VPN Reverse
Proxy](doc/Traefik-VPN-Proxy.jpg)](https://raw.githubusercontent.com/EnigmaCurry/d.rymcg.tech/master/traefik/doc/Traefik-VPN-Proxy.jpg)

Consider the use-case for Traefik as a VPN client:

 * You have a Docker server hosted on the public internet.
 * You run Traefik on your public Docker server, with
   `TRAEFIK_VPN_ENABLED=true`, (this Traefik server can *only* be
   accessed from the private wireguard network)
 * You have an office LAN with multiple clients, all behind an office
   router firewall, they would all like to access your private Traefik
   instance, but they can't access it without a VPN client, and its
   too cumbersome to install the client on all the office computers.
 * So, you configure a small computer in the office (eg. raspberry pi)
   as the only computer that needs to connect to the VPN.
 * The local office Traefik instance runs in the wireguard client
   configuration, with `TRAEFIK_VPN_CLIENT_ENABLED=true` and forwards
   all requests it receives from the local LAN over to the private
   Traefik instance on the VPN.
 * You selectively configure `TRAEFIK_VPN_CLIENT_PEER_SERVICES`, which
   is the list of private services you wish to expose.
 * All the office workers can now access these private VPN services
   with no authorization, but only from the secure office network,
   connecting through the local proxy (rasbperry pi).

Consider adding on to the above use-case with a third internet server:

 * You create a new Docker server on the public internet.
 * You run Traefik on the second docker server, with
`TRAEFIK_VPN_CLIENT_ENABLED=true` connecting to the first docker
server running with `TRAEFIK_VPN_ENABLED=true`.
 * You selectively configure `TRAEFIK_VPN_CLIENT_PEER_SERVICES`, which
   is the list of private services you wish to expose.
 * You can expose any service from any computer connected to the same
   wireguard private network, by creating a Traefik
   service,router,middleware, and serversTransport. Follow the example
   of [vpn-client.yml](config/config-template/vpn-client.yml)
 * Now the allowed private services are exposed to the public
   internet.

To configure Traefik as a VPN client, run `make config`:

 * When you are asked `Do you want to run Traefik exclusively inside a
   VPN?` answer **N**. When you are asked `Do you want to run Traefik
   as a reverse proxy for an external VPN?` answer **Y**.

 * Once you tell `make config` that you want to run the vpn client, it
   will ask you to enter all of the same details found in the output
   of the server's `make show-wireguard-peers`. The crednetials are
   then permantely stored in the traefik .env file.

 * When asked to `Enter the list of VPN service names that the client
   should reverse proxy`, you should enter a list of the names all of
   the private services you want to forward. For example, if you want
   to forward the `whoami` and the `piwigo` services, you would answer
   `whoami,piwigo`

Once reconfigured, run `make install` and the configuration will be
regenerated, creating a new router and middleware to accomplish the
forwarding.

The private Traefik server has configured `TRAEFIK_ROOT_DOMAIN` (eg.
`d.rymcg.tech`) and the Traefik vpn client has a copy of this as
`TRAEFIK_VPN_ROOT_DOMAIN`. It uses this information to translate from
public domain to the private domain.

For example:

 * Suppose the VPN server's private Traefik instance is configured with
   `TRAEFIK_ROOT_DOMAIN=private.example.com`
 * Suppose the VPN client's public Traefik instance is configured with
   `TRAEFIK_ROOT_DOMAIN=public.example.com` and
   `TRAEFIK_VPN_ROOT_DOMAIN=private.example.com`
 * Suppose the VPN server has deployed the `whoami` service and the
   Traefik client server has configured
   `TRAEFIK_VPN_CLIENT_PEER_SERVICES=whoami` in order to forward
   requests to the private whoami service.

In the above scenario, any request coming into the public Traefik
client server for the domain `whoami.public.example.com` will get
translated to the host `whoami.private.example.com` and forwarded to
the private Traefik VPN server instance.

## Environment Variables

Here is a description of every single environment variable in the
Traefik [.env](.env-dist) file :

| Variable name                              | Description                                                                      | Examples                                      |
|--------------------------------------------|----------------------------------------------------------------------------------|-----------------------------------------------|
| (various LEGO DNS variables)               | All of your tokens for DNS provider                                              | `DO_AUTH_TOKEN`                               |
| `DOCKER_COMPOSE_PROFILES`                  | List of docker-compose profiles to enable                                        | `default`,`wireguard`,`wireguard-client`      |
| `TRAEFIK_ACCESS_LOGS_ENABLED`              | (bool) enable the Traefik access logs                                            | `true`,`false`                                |
| `TRAEFIK_ACCESS_LOGS_PATH`                 | The path to the access logs inside the volume                                    | `/data/access.log`                            |
| `TRAEFIK_ACME_CA_EMAIL`                    | Your email to send to Lets Encrypt                                               | `you@example.com` (can be blank)              |
| `TRAEFIK_ACME_CERT_DOMAINS`                | The JSON list of all certificate domans                                          | Use `make certs` to manage                    |
| `TRAEFIK_ACME_CERT_RESOLVER`               | Lets Encrypt API environment                                                     | `production`,`staging`                        |
| `TRAEFIK_ACME_CHALLENGE`                   | The ACME challenge type                                                          | `tls`,`dns`                                   |
| `TRAEFIK_ACME_DNS_PROVIDER`                | The LEGO DNS provider name                                                       | `digitalocean`                                |
| `TRAEFIK_ACME_DNS_VARNAME_1`               | The first LEGO DNS variable name                                                 | `DO_AUTH_TOKEN`                               |
| `TRAEFIK_ACME_DNS_VARNAME_2`               | The second LEGO DNS variable name                                                | leave blank if there are no more              |
| `TRAEFIK_ACME_DNS_VARNAME_3`               | The thrid LEGO DNS variable name                                                 | leave blank if there are no more              |
| `TRAEFIK_ACME_DNS_VARNAME_4`               | The fourth LEGO DNS variable name                                                | leave blank if there are no more              |
| `TRAEFIK_ACME_DNS_VARNAME_5`               | The fifth LEGO DNS variable name                                                 | leave blank if there are no more              |
| `TRAEFIK_ACME_ENABLED`                     | (bool) Enable ACME TLS certificate resolver                                      | `true`,`false`                                |
| `TRAEFIK_CONFIG_VERBOSE`                   | (bool) Print config to logs                                                      | `false`,`true`                                |
| `TRAEFIK_CONFIG_YTT_VERSION`               | YTT tool version                                                                 | `v0.43.0`                                     |
| `TRAEFIK_DASHBOARD_HTTP_AUTH`              | The htpasswd encoded password for the dashboard                                  | `$$apr1$$125jLjJS$$9WiXscLMURiMbC0meZXMv1`    |
| `TRAEFIK_DASHBOARD_ENTRYPOINT_ENABLED`     | (bool) Enable the dashboard entrypoint                                           | `true`, `false`                               |
| `TRAEFIK_DASHBOARD_ENTRYPOINT_HOST`        | The IP address to bind to                                                        | `127.0.0.1` (host networking) `0.0.0.0` (VPN) |
| `TRAEFIK_DASHBOARD_ENTRYPOINT_PORT`        | The TCP port for the daashboard                                                  | `8080`                                        |
| `TRAEFIK_DOCKER_PROVIDER_CONSTRAINTS`      | [Constraints](https://doc.traefik.io/traefik/providers/docker/#constraints) rule | None                                          |
| `TRAEFIK_DOCKER_PROVIDER`                  | (bool) Enable the Traefik docker provider                                        | `true`,`false`                                |
| `TRAEFIK_FILE_PROVIDER_WATCH`              | (bool) Enable automatic file reloading                                           | `false`,`true`                                |
| `TRAEFIK_FILE_PROVIDER`                    | (bool) Enable the Traefik file provider                                          | `true`,`false`                                |
| `TRAEFIK_GEOIPUPDATE_ACCOUNT_ID`           | MaxMind account id for GeoIP database download                                   |                                               |
| `TRAEFIK_GEOIPUPDATE_EDITION_IDS`          | The list of GeoIP databases to download                                          | `GeoLite2-ASN GeoLite2-City GeoLite2-Country` |
| `TRAEFIK_GEOIPUPDATE_LICENSE_KEY`          | MaxMind license key for GeoIP database download                                  |                                               |
| `TRAEFIK_HEADER_AUTHORIZATION_GROUPS`      | JSON list of user groups for OAuth2 authorization                                | `{"admin":["root@localhost"]}`                |
| `TRAEFIK_IMAGE`                            | The Traefik docker image                                                         | `traefik:v2.9`                                |
| `TRAEFIK_LOG_LEVEL`                        | Traefik log level                                                                | `warn`,`error`,`info`, `debug`                |
| `TRAEFIK_MPD_ENTRYPOINT_ENABLED`           | (bool) Enable mpd (unencrypted) entrypoint                                       |                                               |
| `TRAEFIK_MPD_ENTRYPOINT_HOST`              | Host ip address to bind mpd entrypoint                                           | `0.0.0.0`                                     |
| `TRAEFIK_MPD_ENTRYPOINT_PORT`              | Host TCP port to bind mpd entrypoint                                             | `6600`                                        |
| `TRAEFIK_MQTT_ENTRYPOINT_ENABLED`          | (bool) Enable mqtt (port 443) entrypoint                                         |                                               |
| `TRAEFIK_MQTT_ENTRYPOINT_HOST`             | Host ip address to bind mqtt entrypoint                                          | `0.0.0.0`                                     |
| `TRAEFIK_MQTT_ENTRYPOINT_PORT`             | Host TCP port to bind mqtt entrypoint                                            | `8883`                                        |
| `TRAEFIK_NETWORK_MODE`                     | Bind Traefik to host or serivce container networking                             | `host`,`wireguard`,`wireguard-client`         |
| `TRAEFIK_PLUGINS`                          | (bool) Enable Traefik plugins                                                    | `true`,`false`                                |
| `TRAEFIK_PLUGIN_BLOCKPATH`                 | (bool) Enable BlockPath plugin                                                   | `true`,`false`                                |
| `TRAEFIK_PLUGIN_MAXMIND_GEOIP`             | (bool) Enable GeoIP plugin                                                       | `false`, `true`                               |
| `TRAEFIK_ROOT_DOMAIN`                      | The default root domain of every service                                         | `d.rymcg.tech`                                |
| `TRAEFIK_SEND_ANONYMOUS_USAGE`             | (bool) Whether to send usage data to Traefik Labs                                | `false`, `true`                               |
| `TRAEFIK_SNAPCAST_ENTRYPOINT_ENABLED`      | (bool) Enable snapcast (unencrypted) entrypoint                                  |                                               |
| `TRAEFIK_SNAPCAST_ENTRYPOINT_HOST`         | Host ip address to bind snapcast entrypoint                                      | `0.0.0.0`                                     |
| `TRAEFIK_SNAPCAST_ENTRYPOINT_PORT`         | Host TCP port to bind snapcast entrypoint                                        | `1704`                                        |
| `TRAEFIK_REDIS_ENTRYPOINT_ENABLED`         | (bool) Enable redis  entrypoint                                                  |                                               |
| `TRAEFIK_REDIS_ENTRYPOINT_HOST`            | Host ip address to bind redis entrypoint                                         | `0.0.0.0`                                     |
| `TRAEFIK_REDIS_ENTRYPOINT_PORT`            | Host TCP port to bind redis entrypoint                                           | `1704`                                        |
| `TRAEFIK_SSH_ENTRYPOINT_ENABLED`           | (bool) Enable ssh (port 2222) entrypoint                                         | `true`,`false`                                |
| `TRAEFIK_SSH_ENTRYPOINT_HOST`              | Host ip address to bind ssh entrypoint                                           | `0.0.0.0`                                     |
| `TRAEFIK_SSH_ENTRYPOINT_PORT`              | Host TCP port to bind ssh entrypoint                                             | `2222`                                        |
| `TRAEFIK_VPN_ADDRESS`                      | Private VPN IP address of Traefik server                                         | `10.13.16.1`                                  |
| `TRAEFIK_VPN_ALLOWED_IPS`                  | Which IP subnets are routable by the VPN                                         | `10.13.16.0/24`, `0.0.0.0` (all traffic)      |
| `TRAEFIK_VPN_CLIENT_ENABLED`               | (bool)  Enable the VPN client                                                    | `false`,`true`                                |
| `TRAEFIK_VPN_CLIENT_INTERFACE_ADDRESS`     | The VPN client private IP address                                                | `10.13.16.2`                                  |
| `TRAEFIK_VPN_CLIENT_INTERFACE_LISTEN_PORT` | The VPN client listen port                                                       | `51820`                                       |
| `TRAEFIK_VPN_CLIENT_INTERFACE_PEER_DNS`    | The VPN client peer DNS                                                          | `10.13.16.1`                                  |
| `TRAEFIK_VPN_CLIENT_INTERFACE_PRIVATE_KEY` | The VPN client private key                                                       | `4xxxxxxx=`                                   |
| `TRAEFIK_VPN_CLIENT_PEER_ALLOWED_IPS`      | The VPN client allowed routable IP addresses                                     | `10.13.16.1/32`                               |
| `TRAEFIK_VPN_CLIENT_PEER_ENDPOINT`         | The VPN server public endpoint                                                   | `vpn.example.com:51820`                       |
| `TRAEFIK_VPN_CLIENT_PEER_PRESHARED_KEY`    | The VPN client preshared key                                                     | `6xxxxxxx=`                                   |
| `TRAEFIK_VPN_CLIENT_PEER_PUBLIC_KEY`       | The VPN client public key                                                        | `5xxxxxxx=`                                   |
| `TRAEFIK_VPN_CLIENT_PEER_SERVICES`         | The list of VPN services to forward                                              | `whoami,piwigo,freshrss`                      |
| `TRAEFIK_VPN_ENABLED`                      | (bool) enable VPN server                                                         | `false`,`true`                                |
| `TRAEFIK_VPN_HOST`                         | Public hostname of VPN server                                                    | `vpn.example.com`                             |
| `TRAEFIK_VPN_PEERS`                        | The number or list of clients to create                                          | `client1,client2`, `1`                        |
| `TRAEFIK_VPN_PEER_DNS`                     | The DNS server that clients are advertised to use                                | `auto` (uses host), `1.1.1.1`                 |
| `TRAEFIK_VPN_PORT`                         | The TCP port to bind the VPN server to                                           | `51820`                                       |
| `TRAEFIK_VPN_ROOT_DOMAIN`                  | Root domain of the VPN services                                                  | `d.rymcg.tech`                                |
| `TRAEFIK_VPN_SUBNET`                       | The first .0 IP address of the private VPN subnet                                | `10.13.16.0`                                  |
| `TRAEFIK_WEBSECURE_ENTRYPOINT_ENABLED`     | (bool) Enable websecure (port 443) entrypoint                                    | `true`,`false`                                |
| `TRAEFIK_WEBSECURE_ENTRYPOINT_HOST`        | Host ip address to bind websecure entrypoint                                     | `0.0.0.0`                                     |
| `TRAEFIK_WEBSECURE_ENTRYPOINT_PORT`        | Host TCP port to bind websecure entrypoint                                       | `443`                                         |
| `TRAEFIK_WEB_ENTRYPOINT_ENABLED`           | (bool) Enable web (port 80) entrypoint                                           | `true`,`false`                                |
| `TRAEFIK_WEB_ENTRYPOINT_HOST`              | Host ip address to bind web entrypoint                                           | `0.0.0.0`                                     |
| `TRAEFIK_WEB_ENTRYPOINT_PORT`              | Host TCP port to bind web entrypoint                                             | `80`                                          |
| `TRAEFIK_WEB_PLAIN_ENTRYPOINT_ENABLED`     | (bool) Enable web_plain (port 8000) entrypoint                                   | `true`,`false`                                |
| `TRAEFIK_WEB_PLAIN_ENTRYPOINT_HOST`        | Host ip address to bind web_plain entrypoint                                     | `0.0.0.0`                                     |
| `TRAEFIK_WEB_PLAIN_ENTRYPOINT_PORT`        | Host TCP port to bind web_plain entrypoint                                       | `8000`                                        |
