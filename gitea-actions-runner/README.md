# gitea-actions-runner

This container runs [Docker in Docker](https://hub.docker.com/_/docker/)
(`dind`) and a self-hosted gitea actions runner to build docker images from a
git source code repository. The containerized docker server is run without any
root privileges via [sysbox](https://github.com/nestybox/sysbox). Sysbox is an
alternative runc, so that docker can run apps in an unprivileged container, and
to do things that otherwise would require root (docker socket) privileges.

You can use this runner to build docker images *inside* docker.

## Setup

You must install [sysbox](https://github.com/nestybox/sysbox) natively on your
docker host.

You will need a repository on gitea to associate the runner to.

## Config

On your Gitea instance, go to the repository, then `Settings` ->
`Actions` -> `Runner`. Click `New self-hosted runner`. Find the token
on the screen under the `Configure` script (The part right after
`--token`).

Run `make config` and answer the questions:

 * `RUNNER_NAME` - this should be the hostname of the runner container, and will
   be the name shown on the gitea runners page. Don't put any spaces in the
   name.
 * `REPOSITORY` - this should be the full URL to the repository, ie.
   `https://github.com/EnigmaCurry/restic-backup-docker`
 * `RUNNER_TOKEN` - this is the token for the runner, copied from the `Create
   self-hosted runner` page on gitea.

To run multiple runners, setup each with a different
`.env_${DOCKER_CONTEXT}_${INSTANCE}` file.

## Start the action runner

Run `make install`, then check the runners page again and it should show the
name of the runner and the status: `idle`.

## Example build-and-push action

Here is an example action that will build a docker image for a project that has
a `Dockerfile` in the root directory, and then push the image to GitHub's
container registry (`ghcr.io`)

Create a new file in the project repository called
`.gitea/workflows/docker-build-and-push.yml`


```
name: ci

on:
  push:
    branches:
      - 'master'
      - 'main'

jobs:
  docker:
    runs-on: self-hosted
    steps:
      -
        name: Set up QEMU
        uses: docker/setup-qemu-action@v1
      -
        name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v1
        with:
          driver: docker
      -
        name: Login to GitHub Container Registry
        uses: docker/login-action@v1
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set image TAG with lower-cased repository name
        run: |
          echo "TAG=ghcr.io/${REPOSITORY,,}:latest" >>${GITHUB_ENV}
        env:
          REPOSITORY: '${{ github.repository }}'

      -
        name: Build and push
        id: docker_build
        uses: docker/build-push-action@v2
        with:
          push: true
          tags: ${{ env.TAG }}
          file: Dockerfile
```
