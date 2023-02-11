# whoami

[whoami](https://github.com/traefik/whoami) is a tiny Go webserver
that prints os information and HTTP request to output. It is useful as
a basic deployment and connectivity test.

## Config

```
make config
```

This will ask you to enter the domain name to use, and whether or not
you want to configure a username/password via HTTP Basic
Authentication. It automatically saves your responses into the
configuration file `.env_{DOCKER_CONTEXT}`.

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the password if you enabled it (and chose to store it in
`passwords.json`).

## Destroy

```
make destroy
```

This completely removes the container (and would also delete all its
volumes; but `whoami` hasn't got any data to store.)
