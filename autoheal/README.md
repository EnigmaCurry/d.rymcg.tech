# Autoheal

[Docker Autoheal](https://github.com/willfarrell/docker-autoheal) is a
Docker
[`HEALTHCHECK`](https://docs.docker.com/engine/reference/builder/#healthcheck)
monitor. Whereas Docker will already run the specified healthchecks
and mark containers that fail them as `unhealthy`, it does not take
any action upon that check. It would be nice if Docker would
(optionally) restart unhealthy services automatically. While Docker
Swarm has this functionality builtin, it is not enabled for normal
non-swarm Docker daemons. Docker Autoheal is a separate service that
fixes this missing functionality. This service binds to the Docker
socket, and so it receives health notices for all containers, and can
automatically restart those that are unhealthy, based upon
configuration applied in those container's Docker labels.

## Setup

```
make config
```

You must configure autoheal to tell it which of your containers it should watch:

 * Set `AUTOHEAL_CONTAINER_LABEL=all` to watch ALL containers
   indiscriminantly (but only for containers that actually have a
   `HEALTHCHECK`).
 * Otherwise set this to a specific label name, eg.
   `AUTOHEAL_CONTAINER_LABEL=autoheal`, and then only the containers
   with the label `autoheal=true` will be watched (set this label on
   any other container on your Docker host.).

## Install

```
make install
```

## Read the logs

The logs are very quiet: nothing is printed on startup unless there is
an error. When a watched container becomes unhealthy, and if it is
configured to be restarted, you will see a message like this when it
is restarted:

```
autoheal-autoheal-1  | 21-02-2023 21:50:42 Container /unhealthy-example (3cd71f557bc7) found to be unhealthy - Restarting container now with 10s timeout
```

## Example HEALTHCHECK

An [example service](example) is included for how to create a
healthcheck and to test inducing an unhealthy state, and having
autoheal restart it.
