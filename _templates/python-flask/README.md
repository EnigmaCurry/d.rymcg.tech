# Example Flask docker compose project


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
