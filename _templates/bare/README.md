# Example docker compose project

This example wraps [traefik/whoami](https://github.com/traefik/whoami)
as an example of a containerized service, built from Dockerfile.

## Setup

This example project integrates with
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech#readme).
Before proceeding, you must first clone and setup `d.rymcg.tech` on
your workstation.

This project is an example of a so-called
["external"](https://github.com/enigmacurry/d.rymcg.tech#integrating-external-projects)
project to `d.rymcg.tech`, as it does not live in the same source tree
as `d.rymcg.tech`, but makes a link to inherit its Makefiles and to
gain its superpowers.

## Configure

Once
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech#readme) has
been installed, you can come back to this directory.

Run:

```
make config
```

This will create the `.env_{DOCKER_CONTEXT}` configuration file for
your service.

## Install

Run:

```
make install
```

## Open in your web browser

Run:

```
make open
```

## Customizing

The [whoami](whoami) sub-directory contains the source for the image
that this service builds. It is just an example, and can be replaced
with your own Dockerfile for your own service. If you change the name
of the directory, be sure to update the `docker-compose.yaml`
`build.context` as well.

If you don't need to build an image, but instead you want to pull an
image from a docker registry, remove the `build` directive and replace
with `image: your_image_name`, and then you can delete the
[whoami](whoami) directory (no Dockerfile is needed if you are just
pulling a prebuilt image).
