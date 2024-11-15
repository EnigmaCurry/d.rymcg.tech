# glances

[glances](https://github.com/nicolargo/glances) is an open-source system
cross-platform monitoring tool. It allows real-time monitoring of various
aspects of your system such as CPU, memory, disk, network usage etc. It also
allows monitoring of running processes, logged in users, temperatures,
voltages, fan speeds etc. It also supports container monitoring, it supports
different container management systems such as Docker, LXC. The information
is presented in an easy to read dashboard and can also be used for remote
monitoring of systems via a web interface or command line interface. 

## Warning

This container uses the docker flag `network_mode: host`, which gives
unlimited access to your host network. There is also configurable
support for mounting the Docker socket, which provides full root
access to your host. You should not install this unless you completely
trust this service. To enforce the use of Traefik as your entrypoint,
your external firewall should block TCP ports 61208 and 61209.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

It will also ask you if you want Glances to be able to report on container
metrics in addition to the metrics of the host you are installing it on.
In order for Glances to report on container metrics, it requires access to
the host's Docker socket. Be aware that allowing access to the Docker socket
is not safe because it effectively grants full control over the Docker
daemon, enabling a container or attacker to escalate privileges, manipulate
containers, and potentially compromise the host system.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it
(and chose to store it in `passwords.json`).

## Destroy

```
make destroy
```

This completely removes the container and all its volumes.
