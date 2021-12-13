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
environments. Production will generate browser trustable TLS certificates.
