# Creating multiple instances of a service in d.rymcg.tech

By default, each project supports deploying a single instance per
Docker context. The singleton instance environment file is named
`.env_${DOCKER_CONTEXT}_default`, which is contained in each project
subdirectory (eg. `whoami/.env_d.example.com_default`).

If you want to deploy more than one instance of a given project (and
to the same docker context, and from the same source directory), you
need to create a separate environment file for each one. The
convention that the Makefile expects is to name your several
environment files like this: `.env_${DOCKER_CONTEXT}_${INSTANCE_NAME}`
(eg. `whoami/.env_d.example.com_foo`).

Not every project supports instances yet (nor does it make sense to in
some cases), it is opt-in for each project, by including the
[Makefile.instance](_scripts/Makefile.instance) file at the top of
their own Makefile.

By default, all of the `make` targets will use the default
environment, but you can tell it use the instance environment instead,
by setting the `instance` (or `INSTANCE`) variable:

```
make instance=foo config  # Configure a new or existing instance named foo
make instance=bar config  # (Re)configures bar instance
make instance=foo install # This (re)installs only the foo instance
make instance=bar install # (Re)installs only bar instance
make instance=foo ps      # This shows the containers status of the foo instance
make instance=foo stop    # This stops the foo instance
make instance=bar destroy # This destroys only the bar instance

# Show the status of all instances of the current project subdirectory:
make status
```

It may seem tedious to repeat typing `instance=foo` everytime (and its
easy to forget!), so there is a shortcut: `make instance`, which will
ask you to enter an instance name, and then enter a new sub-shell with
the environment variables set for that instance, making it now the
default within the sub-shell, so you don't have to type it anymore:

```
# Use this to create a new instance (or to use an existing one):
# Enter a subshell with the instance temporarily set as the default:
make instance
```

Example:

```
## Example terminal session for creating a new instance of whoami named foo:

$ cd ~/git/vendor/enigmacurry/d.rymcg.tech/whoami
$ make instance
Enter an instance name to create/edit
: foo
Configuring environment file: .env_d.rymcg.tech_foo
WHOAMI_TRAEFIK_HOST: Enter the whoami domain name (eg. whoami.example.com)
: whoami-foo.d.rymcg.tech
WHOAMI_NAME: Enter a unique name to display in all responses
: foo
Set WHOAMI_INSTANCE=foo
## Entering sub-shell for instance foo.
## Press Ctrl-D to exit or type `exit`.

(context=d.rymcg.tech project=whoami instance=foo)
whoami $
```

Inside the sub-shell, the `PS1` Bash prompt has been set so that it
will remind you of your current locked instance:
`(context=d.rymcg.tech project=whoami instance=foo)`. You have access
to all of the same `make` targets as before, but now they will apply
to the instance by default:

```
## Inside of the foo instance sub-shell ...
make config                  # (Re)configures foo instance
make install                 # (Re)installs foo instance
make destroy                 # Destroys foo instance
etc...
```

To exit the sub-shell, press `Ctrl-D` or type `exit` and you will
return to the original parent shell and working directory.

When you create a new instance, `make config` will automatically run. You
may switch to an existing instance with either: `make instance` or
`make switch` (the former will re-run `make config` while the latter
will not).

Note: the sub shell only works temporarily for you to focus on a single app. If
you're doing things outside of that focus, you need to not be in the subshell.

## Overriding docker-compose.yaml per-instance

Most of the time, when you create multiple instances, the only thing
that needs to change is the environment file
(`.env_${DOCKER_CONTEXT}_${INSTANCE}`). Normally the
`docker-compose.yaml` is static and stays the same between several
instances.

However, sometimes you need to configure the `docker-compose.yaml` of
two instances a little bit differently from each other, but mostly
stay the same. You may also wish to modify the configuration without
wanting to commit those changes back to the base template in the git
repository.

You can override each project's `docker-compose.yaml` with a
per-docker-context `docker-compose.override_${DOCKER_CONTEXT}_default.yaml`
(default instance) or a per-instance
`docker-compose.override_${DOCKER_CONTEXT}_${INSTANCE}.yaml` file.

You can find an example of this in the [sftp](sftp) project. Each
instance of sftp will need a custom set of volumes, and since this is
normally a static list in `docker-compose.yaml`, you need a way of
dynamically generating it. There is a template
[docker-compose.instance.yaml](sftp/docker-compose.instance.yaml) that
when you run `make config` it will render the template to the file
`docker-compose.override_${DOCKER_CONTEXT}_default.yaml` containing
the custom mountpoints (this file is ignored by git.) The override
file is merged with the base `docker-compose.yaml` whenever you run
`make install`, thus each instance receives its own list of volumes to
mount.

Reference the Docker compose documentation for [Adding and overriding
configuration](https://docs.docker.com/compose/extends/#adding-and-overriding-configuration)
regarding the rules for how the merging of configuration files takes
place.
