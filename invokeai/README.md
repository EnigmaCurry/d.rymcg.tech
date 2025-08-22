# invokeai

[invokeai](https://github.com/invoke-ai/InvokeAI) is an engine to generate stunning visual media using the latest AI-driven technologies.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{DOCKER_CONTEXT}_{INSTANCE}`.

### AMD GPUs

If you are using ROCm for an AMD GPU, you will need to ensure that the
"render" group within the container and the host system use the same
group ID. Running `make config` will automatically `ssh` into the
current Docker context (i.e., the host), determine the GID of the
"render" group, and add it to your configuration. If you want to
determine it manually, you can run `make get-render-gid` from this
directory, or you can manually run `getent group render` on the host
and note the GID number.

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

## Destroy

```
make destroy
```

This completely removes the container and deletes all its volumes.
