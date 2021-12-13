# Shaarli

[Shaarli](https://github.com/shaarli/Shaarli) is a personal, minimalist,
super-fast, database free, bookmarking service.

Copy `.env-dist` to `.env`, and edit variables accordingly.

 * `SHAARLI_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `SHAARLI_DOCKER_TAG` Shaarli docker tag to use ([available tags](https://shaarli.readthedocs.io/en/master/Docker/#get-and-run-a-shaarli-image))

To start Shaarli, go into the shaarli directory and run `docker-compose up -d`.
