# photoprism

[PhotoPrism®](https://hub.docker.com/r/photoprism/photoprism) is an
AI-Powered Photos App for the Decentralized Web.

## Config

```
make config
```

This will ask you to enter the domain name to use, and whether or not
you want to configure a username/password via HTTP Basic
Authentication. It automatically saves your responses into the
configuration file `.env_{DOCKER_CONTEXT}`.

You'll also be prompted to enter a few configurations for PhotoPrism,
but there are other Photoprism options you can configure by manually
editing your `.env_{DOCKER_CONTEXT}` file. If you add more media volumes,
be sure to add them to `docker-compose.yaml` as well; and if you add an
import volume, be sure to uncomment the corresponding line in the 
`photoprism` service in `docker-compose.yaml` as well.

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
volumes).
