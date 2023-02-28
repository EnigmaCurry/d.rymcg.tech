# Jupyterlab

[Jupyterlab](https://jupyter-docker-stacks.readthedocs.io/en/latest/) is a
progamming notebook, for Python and other languages.

Run `make config` and set the jupyterlab domain name.

Run `make install` to deploy it.

Run `watch make status` and wait for the service to come online with
`HEALTH=healthy`. (Press `Ctrl-C` to quit watch.)

Run `make open` to open the application URL in your browser.

Run `make token` to view the token necessary to login, which is also
found stored in the `.env_{DOCKER_CONTEXT}_{INSTANCE}` config file.

All work saved in `/home/jovyan/work` is saved to a docker volume.

## Extensions

 * https://github.com/kpe/jupyterlab-emacskeys

