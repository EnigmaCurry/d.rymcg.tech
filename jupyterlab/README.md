# Jupyterlab

[Jupyterlab](https://jupyter-docker-stacks.readthedocs.io/en/latest/) is a
progamming notebook, for Python and other languages.

Run `make config` and set the jupyterlab domain name.

Run `make install` to deploy.

Run `make open` to open the application URL in your browser.

All work saved in `/home/jovyan/work` is saved to a the
`jupyterlab_work` docker volume.

The token to access the server changes each time the container starts,
to find the token look at the logs:

```
make logs
```

