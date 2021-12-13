# Baikal

[Baikal](https://sabre.io/baikal/) is a lightweight CalDAV+CardDAV server. 

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `BAIKAL_TRAEFIK_HOST` to the external domain name forwarded from traefik, eg.
   `cal.example.com`
 
To start baikal, go into the baikal directory and run `docker-compose up -d`.

Immediately configure the application, by going to the external URL in your
browser, it is unsecure by default until you set it up!
