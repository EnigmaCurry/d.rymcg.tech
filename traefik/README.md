# Traefik

[Traefik](https://github.com/traefik/traefik) is a modern TLS / HTTP /
TCP / UDP reverse proxy and load balancer. Traefik is the front-most
gateway for (almost) all of the projects hosted by d.rymcg.tech, and
should be the first thing you install in your deployment.

The latest iteration of this config has the following new features:

 * The removal of the `traefik-proxy`, `traefik-wireguard`, and
   `traefik-mail` networks. [Traefik now uses the host
   network](https://github.com/EnigmaCurry/d.rymcg.tech/issues/7) by
   default, and can therefore talk to all service containers directly,
   and so these containers do not need to attach to a specific docker
   network anymore.
 * Traefik can also operate inside of a wireguard VPN, as a server, or
   as a client. The wireguard server and client services have
   internalized to the Traefik docker-compose.yaml and removed as
   separate projects.
 * TLS certificates are now managed via the `make certs` tool and
   added to the central Traefik static configuration. Previously,
   certificate resolver references were inherited by docker labels on
   the individual service containers, and TLS certificates were issued
   on-demand. With these labels now removed, these certificates must
   be created explicitly (via `make certs`) *before* the
   service/routers need them (if not, a default self-signed cert will
   be assigned).
 * The static configuration has been moved away from the
   docker-compose.yaml arguments and into the
   [traefik.yml](config/traefik.yml) template rendered automatically via the
   [ytt](https://carvel.dev/ytt/) tool when you run `make install`.
   (This happens inside the [config](config) container, so you don't
   need to install ytt on your workstation.)

## Config

Open your terminal, and from this directory (`traefik`), run the
interactive configuration wizard:

```
make config
```

Follow the prompts and answer the questions. You will configure the
ACME certificate resolver, and the Traefik dashboard access
credentials.

Next configure the TLS certificates, run:

```
make certs
```

(Follow the [certificate manager](#certificate-manager) section for a
detailed example of creating certificates and then come back here.)

Double check that the config has now been created in your
`.env_${DOCKER_CONTEXT}` file and make any final edits (there are a
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
directly on the endpoint. Therefore you must configure the certificate
domains, *and reinstall Traefik*, before these certificates are needed.

`make certs` is an interactive tool that configures the
`TRAEFIK_ACME_CERT_DOMAINS` variable in the Traefik
`.env_${DOCKER_CONTEXT}` file, which is stored as a JSON list of
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
domains+SANS is saved back into your `.env_${DOCKER_CONTEXT}` file in
the `TRAEFIK_ACME_CERT_DOMAINS` variable as a JSON nested list. When
you run `make install` this is pushed into the [static configuration
template](https://github.com/EnigmaCurry/d.rymcg.tech/blob/e6a4d0285f04d6d7f07fb9a5ec403ba421229747/traefik/config/traefik.yml#L80-L87).

Back at the main menu, type `q` to quit the certificate manager. In
order for the new certificate domains to be loaded, you must reinstall
traefik:

```
make install
```

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
   are ignored by thhe git repository and serve as a local-only config
   store, they are loaded identically as the `config-templates`
   directory.
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
manually copy `.env-dist` to `.env`. Follow the comments inside
`.env-dist` for all the available options. Here is a description of
the most relevant options to edit:

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
 * `TRAEFIK_DASHBOARD_AUTH` this is the htpasswd encoded username/password to
   access the Traefik API and dashboard. If you ran `make config` this would be
   filled in for you, simply by answering the questions.

Each entrypoint can be configured on or off, as well as the explicit
host IP address and port number:
 * `TRAEFIK_WEB_ENTRYPOINT_ENABLED=true` enables the HTTP entrypoint,
   which is only used for redirecting to `websecure` entrypoint. Use
   `TRAEFIK_WEB_ENTRYPOINT_HOST` and `TRAEFIK_WEB_ENTRYPOINT_PORT` to
   customize the host (default `0.0.0.0`) and port number (default
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
 * [geoip2](https://github.com/GiGInnovationLabs/traefikgeoip2) -
   middleware that adds headers containing geographic location based
   upon IP address. (Enable by setting
   `TRAEFIK_PLUGIN_MAXMIND_GEOIP=true`)
   ([whoami](../whoami/docker-compose.yaml) has an example)

You can add third party plugins by modifying the
[Dockerfile](Dockerfile), and follow the example of blockpath.

You also need to [add your plugin to the traefik static
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

You can start the [traefik-forward-auth](../traefik-forward-auth) service to
enable OAuth2 authentication to your [gitea](../gitea) identity provider.

## Wireguard VPN

By default Traefik is setup to use the `host` network, which is used
for *public* servers. Alternatively, you can start a wireguard VPN
server and run Traefik inside of the VPN network exclusively. As a
third configuration, you can have a public Traefik server reverse
proxy to a private VPN network.

The easiest way to configure either the VPN server or client, is to
run the `make config` script. Watch for the following questions to
turn the wireguard services on:

 * `Do you want to run Traefik exclusively inside a VPN?` Say yes to
   this question to configure the wireguard server.
 * `Do you want to run Traefik as a reverse proxy for an external
   VPN?` Say yes to this question to configure the wireguard client.

