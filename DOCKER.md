# Docker

This guide will document how to install a Docker server on an existing
Linux host.

## Requirements

 * You will need an existing Linux server or VM (amd64 or aarch64)
   running Debian (recommended), Raspbian, Ubuntu, Fedora, or RHEL
   (supported by
   [docker-install](https://github.com/docker/docker-install/tree/master)).
   It should be a fresh install, with no other services running yet
   (excpet for basic system services like SSH or collectd).

* You should also have your workstation already setup:

   * [WORKSTATION_LINUX.md](WORKSTATION_LINUX.md) - Setup your workstation on Linux.
   * [WORKSTATION_WSL.md](WORKSTATION_WSL.md) - Setup your workstation on Windows (WSL)
 
## Setup SSH and Docker context

From your workstation, run:

```
d context new
```

This will confirm that you want to create a new context:

```
> This command can help create a new SSH config and Docker context. Proceed? Yes
```

It will ask if you want to create the SSH host config, or to use an
existing one from `~/.ssh/config` (this example shows to create a new
entry after pressing the down arrow key):

```
? You must specify the SSH config entry to use  
  I already have an SSH host entry in ~/.ssh/config that I want to use
> I want to make a new SSH host entry in ~/.ssh/config
```

Enter the context name. This should be a short recognizable name (no
spaces). E.g., `widgets-prod`:

```
> Enter the new SSH context name (short host name) : widgets-prod
```

Enter the domain name or IP address of your Docker server:

```
> Enter the fully qualified SSH Host DNS name or IP address : widgets-prod.example.com
```

Confirm that you want to save the config:

```
> Do you want to append this config to ~/.ssh/config? Yes
```

Switch context to this context at any time:

```
d context
```

Choose the context you want to switch to:

```
? Select the Docker context to use  
  d-test
  insulon
> widgets-prod
[↑↓ to move, enter to select, type to filter, ESC to cancel]
```

With the correct context selected, the `d.rymcg.tech` and `d` alias
will now affect that contexts remote Docker server.

## Install Docker

Make sure the correct context is selected:

```
d context
```

To install Docker, run this command:

```
d install-docker
```

The first time you are connecting, you need to confirm the SSH host
key (type `yes`):

```
The authenticity of host '1.2.3.4 (1.2.3.4)' can't be established.
ED25519 key fingerprint is SHA256:MJXpZH1KbzwJqvoR6gpMCR/p1CKocQwqgd7cDncpxHo.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '1.2.3.4' (ED25519) to the list of known hosts.
```

Watch the output for messages of success or failure. After successful
installation, it should show:

```
docker-test systemd[1]: Started docker.service - Docker Application Container Engine.
```

If you are running an unsupported Linux distribution, you should
consult your own vendor documentation (e.g., Docker on [Arch
Linux](https://wiki.archlinux.org/title/Docker)) or the upstream
[Docker Engine](https://docs.docker.com/engine/install/#server)
documentation.
