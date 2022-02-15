# Traefik

[Traefik](https://github.com/traefik/traefik) is a modern
HTTP reverse proxy and load balancer.

## Config

Run `make config` or copy `.env-dist` to `.env` and edit the following:

 * `ACME_CA_EMAIL` this is your personal/work email address, where you will
   receive notices from Let's Encrypt regarding your domains and related
   certificates or if theres some other problem with your account.
 * `TRAEFIK_DASHBOARD_AUTH` this is the htpasswd encoded username/password to
   access the Traefik API and dashboard. If you ran `make config` this would be
   filled in for you, simply by answering the questions.
   
One of the questions `make config` will ask you is if you would like to save
`passwords.json` into this same directory. This file is not created by default,
but only if you answer yes to this question. `passwords.json` will store the
plain text password for the dashboard to make it easier to log in (`make open`
will automatically open your browser to the dashboard, filling in the
username/password for you, read from `passwords.json`).

To start Traefik, run `make install` or `docker-compose up -d`.

## Dashboard

Traefik includes a dashboard to help visualize your configuration and detect
errors. The dashboard service is only exposed to the localhost of the server, so
you must tunnel throuh SSH to your docker server in order to see it:

```
ssh -N -L 8080:localhost:8080 ssh.example.com &
```

With the tunnel active, you can view
[https://localhost:8080/dashboard/](https://localhost:8080/dashboard/) in your
web browser to access it.

You can quickly do all of the above by running the Makefile target:

```
# Starts the SSH tunnel if its not already running, 
# and automatically opens your browser, 
# prefilling the username/password if its available in passwords.json:
make open
```

You can `make close` later if you want to close the SSH tunnel.

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

For most configuration, you should use the Traefik Docker provider. This means
that you put all traefik configuration directly in Docker labels on the service
containers you create. 

You can also put your configuration into files. The docker-compose will render
templates from the [config/config-template](config/config-templates) directory
everytime before Traefik starts.
