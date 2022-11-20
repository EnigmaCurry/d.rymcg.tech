# _scripts

This directory contains *optional* bash scripts to help the Makefiles configure
things. You shouldn't run any of these scripts directly, they are meant only to
be called from the Makefiles.

## What's optional exactly?

Every project here is created to be a simple docker-compose project,
configured *entirely* by static `.env_${DOCKER_CONTEXT}_default`
files. So you won't need *any* scripts nor Makefiles, as long as you
edit the `.env_${DOCKER_CONTEXT}_default` files by hand, and just run
`docker-compose` directly.

These are helpers only, to help create
`.env_${DOCKER_CONTEXT}_default` files, and to automate repetitive
admin tasks.
