# Container Workstation in Docker

This is a development container that includes the Bash shell and the
docker command line tools, to be used as a "workstation" with
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech).

This is the default container installed via the root
[compose-dev.yaml](../../compose-dev.yaml), which is automatically
used when creating a [Docker Desktop Dev
Environment](https://docs.docker.com/desktop/dev-environments/set-up/).
This is a competing solution to the [Nix user
container](https://github.com/EnigmaCurry/d.rymcg.tech/pull/32);
rather than using a complex nix configuration, this one is just a
simple Dockerfile to bootstrap from the Debian image.

