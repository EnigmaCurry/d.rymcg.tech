# Plausible

[Plausible](https://github.com/plausible/analytics) is a privacy
respecting website visitor analytics engine.

## Config

Run `make config` and set the plausible domain name. You can choose to
allow or disallow registations, or to allow by invitation only.

Run `make install` to deploy.

Run `make open` to open the application URL in your browser.

Even if you disable registrations, you must still immediately register
the first account.

## Start the server

Once your `.env_${DOCKER_CONTEXT}_default` file is configured, start the
service:

```
make install
```

## Setup

Just navigate to the url and create your account.

Then follow the instructions for a new website and insert the snippet into your site.

## Todo
 - readme about database volumes, backup
