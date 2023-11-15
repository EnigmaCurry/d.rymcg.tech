# photoprism

[PhotoPrism®](https://hub.docker.com/r/photoprism/photoprism) is an
AI-Powered Photos App for the Decentralized Web.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.


You'll also be prompted to enter a few configurations for PhotoPrism,
but there are other Photoprism options you can configure by manually
editing your `.env_{DOCKER_CONTEXT}` file. If you add more media volumes,
be sure to add them to `docker-compose.yaml` as well; and if you add an
import volume, be sure to uncomment the corresponding line in the 
`photoprism` service in `docker-compose.yaml` as well.

### Authentication and Authorization

Running `make config` will ask whether or not you want to configure
authentication for your app (on top of any authentication your app provides).
You can configure OpenID/OAuth2 or HTTP Basic Authentication.

OAuth2 uses traefik-forward-auth to delegate authentication to an external
authority (eg. a self-deployed Gitea instance). Accessing this app will
require all users to login through that external service first. Once
authenticated, they may be authorized access only if their login id matches the
member list of the predefined authorization group configured for the app
(`PHOTOPRISM_OAUTH2_AUTHORIZED_GROUP`). Authorization groups are defined in the
Traefik config (`TRAEFIK_HEADER_AUTHORIZATION_GROUPS`) and can be
[created/modified](https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/traefik/README.md#oauth2-authentication)
by running `make groups` in the `traefik` directory.

For HTTP Basic Authentication, you will be prompted to enter username/password
logins which are stored in that app's `.env_{INSTANCE}` file.


## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it (and chose
to store it in `passwords.json`).

Photoprism also has it's own authentication, and the initial password for
the "admin" account (whatever you entered for `PHOTOPRISM_ADMIN_USER`)
is "password". You should change this from within Photoprism.

## Destroy

```
make destroy
```

This completely removes the container (and would also delete all its
volumes).
