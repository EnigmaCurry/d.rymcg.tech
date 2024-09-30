# drawio

[drawio](https://github.com/jgraph/drawio) is an open source browser
based diagram tool. This deployment uses the
[jgraph/docker-drawio](https://github.com/jgraph/docker-drawio) docker
image.

Note: this image is not working on arm64.

## Configure

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


```
make open
```
