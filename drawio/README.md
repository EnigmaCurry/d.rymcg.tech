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

Enter `DRAWIO_TRAEFIK_HOST` as the domain name you want to serve as,
eg. `diagram.example.com`.

## Install

```
make install
```


```
make open
```
