# Traefik

[Traefik](https://github.com/traefik/traefik) is a modern
HTTP reverse proxy and load balancer.

Copy `.env-dist` to `.env` and edit the following:

 * `ACME_CA_EMAIL` this is YOUR email address, where you will receive notices
   from Let's Encrypt regarding your domains and related certificates.

To start Traefik, go into the traefik directory and run `docker-compose up -d`

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

## Certificate Resolver

Traefik is configured for Let's Encrypt to issue TLS certificates for all
project (sub-)domain names.

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

## Test the whoami container

For a simple test of Traefik, consider installing the [whoami](../whoami)
project. This will demonstrate a valid TLS certificate, and routing Traefik to
web servers running in project containers.


## OAuth2 authentication

You can start the [traefik-forward-auth](../traefik-forward-auth) service to
enable OAuth2 authentication to your [gitea](../gitea) identity provider.
