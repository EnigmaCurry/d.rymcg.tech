# Traefik

[Traefik](https://github.com/traefik/traefik) is a modern
TLS / HTTP / TCP / UDP reverse proxy and load balancer.

## Config

Run `make config` or copy `.env-dist` to `.env` and edit the following:

 * `ACME_CA_EMAIL` this is your personal/work email address, where you will
   receive notices from Let's Encrypt regarding your domains and related
   certificates or if theres some other problem with your account.
 * `TRAEFIK_DASHBOARD_AUTH` this is the htpasswd encoded username/password to
   access the Traefik API and dashboard. If you ran `make config` this would be
   filled in for you, simply by answering the questions.
   
In order to provide easier routing between each docker-compose project, static
IP addresses and subnets are configured for Traefik. You should configure all of
these networks even if you're not planning on using them all yet.

 * `TRAEFIK_PROXY_SUBNET` - Choose a unique network subnet for the main
   `traefik-proxy` network, eg. `172.13.0.0/16` and choose a specific IP address
   `TRAEFIK_PROXY_SUBNET_IP`, eg. `172.13.0.3`. Most applications that will be
   exposed to the internet will be connected to the `traefik-proxy` subnet.
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

To start Traefik, run `make install` or `docker-compose up -d`.

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

## Certificate Resolver

Traefik is configured for Let's Encrypt to issue TLS certificates for all
project (sub-)domain names. All certificates are stored inside the
`traefik_traefik` Docker volume.

All other services defines the `ACME_CERT_RESOLVER` variable in their respective
`.env` file. There are two different environments defined, `staging` and
`production`. Staging will create untrusted TLS certificates for testing
environments. Production will generate browser trustable TLS certificates. NOTE:
Because Traefik only has a single trust store, you cannot freely switch between
staging and production. For each new domain name, you must decide if that domain
name is going to be forever used for staging or production. You cannot "promote"
a staging domain to a production domain. (You can do so manually, if needed, by
editing the acme.json file in the traefik data volume, and removing the domain's
configuration.)

Note that the default `ACME_CERT_RESOLVER` has been set to `production`. Traefik
does a good job of saving all of your certificates in its own named volume
(`traefik_traefik`), so as long as you're planning on leaving Traefik installed
long term, `production` is generally the better choice *even for development or
testing purposes*. Only choose `staging` if you are not planning on leaving
Traefik installed, or if you have some other testing purpose for doing so.

## Test the whoami container

For a simple test of Traefik, consider installing the [whoami](../whoami)
project. This will demonstrate a valid TLS certificate, and routing Traefik to
web servers running in project containers.


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
