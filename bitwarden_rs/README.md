# Bitwarden

[Bitwarden](https://bitwarden.com/) is an open-source password manager.

Run `make config` or copy `.env-dist` to `.env`, and edit variables
accordingly.

 * `BITWARDEN_PORT` the external port you'll use to connect to Bitwarden.

To start Bitwarden, go into the bitwarden directory and run `docker-compose up -d`.

This configuration uses an SSH tunnel and does not use Traefik. To open the applicaiton in your browser, run:

```
make open
```

Or create the SSH tunnel manually, eg. if you set the port to 8888:

```
ssh docker -L 8888:localhost:8888
```

Then in your web browser, access `http://localhost:8888`
