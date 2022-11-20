# Baikal

[Baikal](https://sabre.io/baikal/) is a lightweight CalDAV+CardDAV server. 

Run `make config` or copy `.env-dist` to `.env_${DOCKER_CONTEXT}_default`, and edit variables
accordingly.

 * `BAIKAL_TRAEFIK_HOST` to the external domain name forwarded from traefik, eg.
   `cal.example.com`

Run `make install`

Immediately configure the application, it is unsecure by default until
you set it up!

Run `make open`
