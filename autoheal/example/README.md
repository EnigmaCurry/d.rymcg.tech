# Example for unhealthy HEALTHCHECK

This service is a simple example that shows a Docker
[`HEALTHCHECK`](https://docs.docker.com/engine/reference/builder/#healthcheck)
and a test for inducing an unhealthy state.

```
make config
```

choose the value for `TIMEOUT` in seconds. If you set this to a value
less than 30, the service will be considered healthy, otherwise
unhealthy.
```
make install
```

With the example service now running, watch the status:

```
watch make status
```

Check the output of the status for the current health. It should
initially say `starting` until the healthcheck either succeeds or
fails. The healthcheck requires the timeout to occur up to three
times, with 30s in between checks; so after ~2mins it should change to
either `healthy` or `unhealthy`.

The service has the label `autoheal=true`, so if you are running the
[autoheal](../README.md) service, the unhealthy service should be
automatically restarted (otherwise the service will run forever in the
unhealthy state).


