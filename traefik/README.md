# Traefik

[Traefik](https://github.com/traefik/traefik) is a modern
HTTP reverse proxy and load balancer.

Copy `.env-dist` to `.env` and edit the following:

 * `ACME_CA_EMAIL` this is YOUR email address, where you will receive notices
   from Let's Encrypt regarding your domains and related certificates.

To start Traefik, go into the traefik directory and run `docker-compose up -d`

All other services defines the `ACME_CERT_RESOLVER` variable in their respective
`.env` file. There are two different environments defined, `staging` (default)
and `production`. Staging will create untrusted TLS certificates for testing
environments. Production will generate browser trustable TLS certificates. NOTE:
Because Traefik only has a single trust store, you cannot freely switch between
staging and production. For each new domain name, you must decide if that domain
name is going to be used for staging or production. You cannot "promote" a
staging domain to a production domain. (You can do so manually, if needed, by
editing the acme.json file in the traefik data volume, and removing the domain's
configuration.)

For a simple test of Traefik, consider installing the
[whoami](../whoami/README.md) project.
