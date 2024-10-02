# 13ft

[13ft](https://github.com/wasi-master/13ft) is a simple self hosted server
that has a simple but powerful interface to block ads, paywalls, and other
nonsense.

## Note

The directory and service for "13ft" are named "thirteenft" due to
naming requirements of environment variables and docker services.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it
(and chose to store it in `passwords.json`).

In addition to using 13ft from its web interfact, you can also append the url
of the site you want to view at the end of the URL for 13ft and it will also
work. (e.g if your server is running at http://127.0.0.1:5000 then you can
go to http://127.0.0.1:5000/https://example.com and it will read out the
contents of https://example.com)s

## Destroy

```
make destroy
```

This completely removes the container and volumes.
