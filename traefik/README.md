# Traefik

[Traefik](https://github.com/traefik/traefik) is a modern
TLS / HTTP / TCP / UDP reverse proxy and load balancer.

## Config

Run `make config` to run the configuration wizard, or manually copy
`.env-dist` to `.env` and then edit the following:

 * `TRAEFIK_ACME_CA_EMAIL` this is your personal/work email address, where you will
   receive notices from Let's Encrypt regarding your domains and related
   certificates or if theres some other problem with your account.
 * `TRAEFIK_ACME_DNS_CHALLENGE` set to `true` or `false` to use the
   ACME DNS-01 challenge type for requesting new certificates.
 * `TRAEFIK_ACME_TLS_CHALLENGE` set to `true` or `false` to use the
   ACME TLS-ALPN-01 challenge type for requesting new certificates.
 * `TRAEFIK_CERT_ROOT_DOMAIN` the main domain name for the default TLS
   certificate. (eg. `d.rymcg.tech`)
 * `TRAEFIK_CERT_SANS_DOMAIN` a comma separated list of secondary
   domain names to include on the default TLS cerificate. If you are
   using the DNS-01 challenge type, you can include wildcard domains
   here (eg. `*.d.rymcg.tech,foo.example.com`).
 * `TRAEFIK_DASHBOARD_AUTH` this is the htpasswd encoded username/password to
   access the Traefik API and dashboard. If you ran `make config` this would be
   filled in for you, simply by answering the questions.

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

In order to provide easier routing between each docker-compose project, static
IP addresses and subnets are configured for Traefik. You should configure all of
these networks even if you're not planning on using them all yet:

 * `TRAEFIK_WIREGUARD_SUBNET` - Choose a unique network subnet for the
   `traefik-wireguard` network, eg. `172.15.0.0/16` and choose a specific IP
   address `TRAEFIK_PROXY_SUBNET_IP`, eg. `172.15.0.3`. This subnet is used for
   connecting the [wireguard](../wireguard) server to Traefik.
 * `TRAEFIK_MAIL_SUBNET` - Choose a unique network subnet for the `traefik-mail`
   network, eg. `172.16.0.0/16` and choose a specific IP address
   `TRAEFIK_PROXY_SUBNET_IP`, eg. `172.16.0.1`. The mail subnet is for exclusive
   use by the (optional) [mailu](../mailu) suite.

In general, you can just use all of the default values suggested by `make
config`, assuming that the suggested subnets are not used by anything else.

One of the questions `make config` will ask you is if you would like to save
`passwords.json` into this same directory. This file is not created by default,
but only if you answer yes to this question. `passwords.json` will store the
plain text password for the dashboard to make it easier to log in (`make open`
will automatically open your browser to the dashboard, filling in the
username/password for you, read from `passwords.json`).

To start Traefik, run `make install` (or `docker-compose up -d`).

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

If you don't wish to use the Makefile, you can do it manually:

Find the Traefik IP address:

```
docker inspect traefik | jq -r '.[0]["NetworkSettings"]["Networks"]["traefik-proxy"]["IPAddress"]'
```

And tunnel the dashboard connection through SSH:

```
ssh -N -L 8080:${TRAEFIK_IP}:8080 ssh.example.com &
```

With the tunnel active, you can view
[https://localhost:8080/dashboard/](https://localhost:8080/dashboard/) in your
web browser to access it. Enter the username/password you configured.

## Install the whoami container

Consider installing the [whoami](../whoami) container, which will
demonstrate a valid TLS certificate, and an example of routing Traefik
to web servers running in project containers.

## OAuth2 authentication

You can start the [traefik-forward-auth](../traefik-forward-auth) service to
enable OAuth2 authentication to your [gitea](../gitea) identity provider.

## File provider

For most configuration, you should use the [Traefik Docker
provider](https://doc.traefik.io/traefik/providers/docker/). This means that you
put all traefik configuration directly in Docker labels on the service
containers you create.

You can also put your configuration into files in YAML or TOML format. The
docker-compose will render templates from the
[config/config-template](config/config-template) directory everytime before
Traefik starts. This entire directory is ignored in `.gitignore`, letting you
create your own private configuration templates.
