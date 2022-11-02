# CryptPad

[CryptPad](https://cryptpad.fr/) is an encrypted, open source office
collaboration suite.

CryptPad is designed to serve its content over two domains. Account passwords
and cryptographic content is handled on the 'main' domain, while the user
interface is loaded from a 'sandbox' domain.

Run `make config` or copy `.env-dist` to `.env`, and edit these
variables:

 * `CRYPTPAD_TRAEFIK_HOST` the external domain name to forward from traefik for
 the main site.
 * `CRYPTPAD_SANDBOX_DOMAIN` the external domain name to forward from traefik for
 sandboxed content.
 * Leave the default `ADMIN_KEY` as-is, until after you start cryptpad the first
   time.

Start cryptpad: `make install`

Visit the main domain in your browser, and register a new account. Go to the
user settings page, and find your public signing key (example:
`[cryptpad-user1@my.awesome.website/YZgXQxKR0Rcb6r6CmxHPdAGLVludrAF2lEnkbx1vVOo=]`)

Edit your `.env` once again, and copy and paste your public signing key into the
`ADMIN_KEY` variable, and restart cryptpad: `make install`
