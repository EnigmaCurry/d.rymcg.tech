# immich

[immich](https://github.com/immich-app) is a high-performance self-hosted
solution for backing up, viewing, managing, and sharing photos from your phone
or existing galleries.

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

### Host Configuration

If the Redis container might throw the following warning, you should configure
your host as needed:
```
WARNING Memory overcommit must be enabled! Without it, a background save or
replication may fail under low memory condition. Being disabled, it can can
also cause failures without low memory condition, see
https://github.com/jemalloc/jemalloc/issues/1328. To fix this issue add
'vm.overcommit_memory = 1' to /etc/sysctl.conf and then reboot or run the
command 'sysctl vm.overcommit_memory=1' for this to take effect.
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it
(and chose to store it in `passwords.json`).

The first person to visit the app will be prompted to create the admin account.

## Destroy

```
make destroy
```

This completely removes the container and volumes.
