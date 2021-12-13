# xBrowserSync

[xBrowserSync](http://www.xbrowsersync.org) is a free tool for syncing browser data between different browsers
and devices, built for privacy and anonymity.

Copy `.env-dist` to `.env`, and edit variables accordingly.

 * `XBS_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `DB_USERNAME` a user name of your choosing.
 * `DB_PASSWORD` a password of your choosing.

Optional: copy xbs/api/settings-dist.json to xbs/api/settings.json and edit to
include any custom settings you wish to run on your service. Important:
the db.host value should match the container name of the "db" service in
xbs/docker-compose.yml.

To start xBrowseySync, go into the xbs directory and run `docker-compose up -d`.
