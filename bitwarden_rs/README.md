# Bitwarden

[Bitwarden](https://bitwarden.com/) is an open-source password manager.

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `BITWARDEN_PORT` the external port you'll use to connect to Bitwarden.

To start Bitwarden, go into the bitwarden directory and run `docker-compose up -d`.

This configuration doesn't use Traefik - you should SSH tunnel into the
host, then access Bitwarden via localhost:<whatever port you designate in .env>

E.g., if you set the port to 8888:

```
ssh docker -L 8888:localhost:8888
```

Then in your web browser, access `http://localhost:8888`
