# nix-user

This is a containerized "workstation" for
[d.rymcg.tech](../../README.md). You can create this as an admin
container to manage *other* docker hosts with d.rymcg.tech. This keeps
your .env files seperate per admin container (ie. one admin container
per docker context to manage).

# Config

```
# If you want configure the 'default' instance:
make config

# If you want to configure a named instance:
make instance
```

# Install

```
make install
```

# Shell

```
make shell
```

You will enter the container sub-shell. The
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) git
repository will automatically be cloneed to
`/home/nix-user/git/vendor/enigmacurry/d.rymcg.tech`. The eponymous
[`d.rymcg.tech`](../../README.md#using-the-drymcgtech-cli-script-optional)
command line script is pre-installed on the `PATH`.

You now need to create your ssh config file and create your remote
docker contexts.

