# Jupyterlab

[Jupyterlab](https://jupyter-docker-stacks.readthedocs.io/en/latest/) is a
progamming notebook, for Python and other languages.

Copy `.env-dist` to `.env` and edit the variables accordingly.

All work saved in /home/jovyan/work is saved to a volume.

The token to access the server changes each time the container starts, to find
the token look at the logs:

```
docker logs jupyterlab
```

