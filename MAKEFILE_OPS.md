# Makefile Docker Ops

This is a guide on how to use the optional Makefiles included with all
projects hosted by
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech). The
Makefiles are an abstraction on top of a pure `docker compose`
backend, to help simplify configuration and maintainance tasks.

The essential information is already written in the main d.rymcg.tech
[README](README.md), but this guide will expand on the topic and walk through more
of the commands available.

## Prerequisites

Follow the installation steps outlined in the main
[README](https://github.com/EnigmaCurry/d.rymcg.tech) (`Install
optional workstation tools`), this will install Make and all the other
tools you need.

## A general introdcution to GNU Make

[GNU Make](https://www.gnu.org/software/make/) is a general
abstraction for any set of software tasks by creating short names for
the tasks (called targets) that you can run on the command line. What
the tasks do could be anything, from building source code, installing
software, or running programs with complex arguments and
configuration. By placing a `Makefile` in the root of your project,
you are enabling your users to run your program the correct way, by
placing the exact recipe in the `Makefile`.

Make is pretty old, and there are many alternatives. But the
prevalence of Make is precisely what makes it possible to quickly
express your intent to new users, and create powerful command line
abstractions.

### The Makefile

The first thing to know about `make`, is that it is contextual to your
current working directory. It will look for instructions in a file
called `Makefile` in the same directory.

The format of a Makefile is very precise. It is recommended to use an
editor (eg. Emacs) that understands the Makefile format. Specifically,
Makefile requires to use tabs instead of spaces to indent blocks. An
editor that knows this, will take care of doing it correctly.

Create a test directory somewhere, and create a new file called
`Makefile`. A basic `Makefile` looks like this:

```
task:
	@echo hi this is the task
```

(Notice the whitespace indentation is a single TAB character).

The part that says `task:` is the Make "target", you can type any
target (or any list of targets) as arguments to the `make` command,
and it will run them (in series):

Open a terminal in the same directory as the `Makefile`, and run:

```
make task
```

You should see the output:
```
hi this is the task
```

The indented part that says `@echo hi this is the task` is any regular
shell command. You can list several commands on new lines, each line
indented with a single tab character. By default, Make wants to inform
you of everything it does, so it prints every command in the task. The
`@` symbol in front tells Make not to echo the command itself. If you
omit the `@` symbol, it will perhaps confusingly print this instead:

```
echo hi this is the task
hi this is the task
```

One important thing to know about Make is that it is designed with the
default assumption that a target produces a file output. This is a
great assumption to make when building software (turning source code
into executable files). However, for many admin tasks you don't want
to produce any output, you just want to run some kind of task.

To exemplify the default assumption of make, create a new blank file
in the same directory called `task`, and then try to run the target:

```
touch task
make task
```

Since a file exists with the same name as the target, make prints this
output:

```
make: 'task' is up to date.
```

So its important to know that `make` will **not** run the target if a
file exists with the same name. To prevent this, you need to use a bit
of boiler-plate, and mark the task as `PHONY`:

```
.PHONY: task
task:
	@echo hi this is the task
```

Marking a target as `PHONY` just means that it bypasses the normal
mode of checking if a file exists with the same name. Now if you run
`make task`, it does not matter if the file `task` exists or not, it
will run the target regardless.

Writing `.PHONY: <target>` in front of every single target may look
weird and tedious, but it will also serve a useful purpose in
self-documentation, which is described a bit later.

### Additional Make targets and accessing variables

A Makefile can have as many differently named targets as you want.

```
.PHONY: task
task:
	@echo hi this is the task.
	@echo I can have multiple lines.

.PHONY: task2
task2:
	@echo hello ${USER} this is another task.

.PHONY: time
time:
	@echo The current time is $$(date).
```

Now you can run each target separately:

```
$ make task
hi this is the task.
I can have multiple lines.

$ make task2
hello ryan this is another task.

$ make time
The current time is Wed Nov 16 03:37:02 PM PST 2022.
```

Or you can run all three together in series:

```
$ make task task2 time
hi this is the task.
I can have multiple lines.
hello ryan this is another task.
The current time is Wed Nov 16 03:37:41 PM PST 2022.
```

Notice that `make task2` inherited the `USER` environment variable
from the parent shell process, indicating the current username. From
inside the Makefile, `${USER}` is treated as a Make variable (not a
shell variable, even though the value came from the parent shell), and
is referenced with a single `$` symbol. Importantly, the variable is
resolved to a string *before* the task is run.

As opposed to a Make variable (eg. USER), to reference any shell
variable, or expansion containing `$`, you must always use two `$$`
symbols in any `Makefile`. In the `make time` example we want to get
the current time when the task is run (not the time before the task is
run). To capture the time in BASH, you would normally write `$(date)`.
But in Make, you must escape it like `$$(date)`.

Make will never attempt to run a target twice, so this only runs the
task once, and produce a warning for subsequent calls:

```
$ make task task task task
hi this is the task.
I can have multiple lines.
make: Nothing to be done for 'task'.
make: Nothing to be done for 'task'.
make: Nothing to be done for 'task'.
```

Make accepts named arguments (not positional), so you can override the
USER variable using any of these methods:

```
## USER is set by your current shell environment:
$ echo $USER
ryan
$ make task2
hello ryan this is another task.

## Override with named arguments after the task name:
$ make task2 USER=foo
hello foo this is another task.

## Override named arguments before the task name (no difference):
$ make USER=foo task2
hello foo this is another task.

## Override environment variables in front of make (no difference):
$ USER=foo make task2
hello foo this is another task.

## Reset the shell variable itself:
$ USER=foo
$ echo $USER
foo
$ make task2
hello foo this is another task.

## Unset USER and make will print a blank USER:
$ unset USER
$ make task2
hello this is another task.
```

### Including other Makefiles

You can include other Makefiles inside of Makefiles. This lets you
make reusable components. d.rymcg.tech contains several Makefile
includes in the [_scripts](_scripts) directory.

```
include ../_scripts/Makefile.help
include ../_scripts/Makefile.build
include ../_scripts/Makefile.globals
include ../_scripts/Makefile.install
include ../_scripts/Makefile.clean
include ../_scripts/Makefile.override
include ../_scripts/Makefile.lifecycle
include ../_scripts/Makefile.open
include ../_scripts/Makefile.reconfigure
include ../_scripts/Makefile.instance
include ../.env_$(shell ${BIN}/docker_context)
```

### Self documentation

Put this at the top of your Makefile to add self-documentation
support:

```
.PHONY: help # Show this help screen
help:
	@grep -h '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/make \1 \t- \2/' | expand -t20
```

Now add your other targets to the same Makefile underneath the `help`
target, this time with comments after the `.PHONY` line, starting with
`#` to mark the comment:

```
.PHONY: task # Run task 1
task:
	@echo hi this is the task
	@echo I can have multiple lines.

.PHONY: task2 # Run task 2
task2:
	@echo hello ${USER} this is another task.

.PHONY: time # Output the current time
time:
	@echo The current time is $$(date)
```

These comments are automatically parsed by the bespoke `help` target,
so you can print the help:

```
$ make help
make help           - Show this help screen
make task           - Run task 1
make task2          - Run task 2
make time           - Output the current time
```

Make doesn't have a help system by default, we had to make our own, so
having to type `.PHONY:` in front of all our targets turned out to be
pretty useful and less like boilerplate.

If you just type `make` without any target, the `help` target will
automatically run because its the first target listed in the
`Makefile`, and give the user some helpful output. If you type `make`
and hit the TAB key, your shell should output completion suggestions
(assuming `bash-completion` or similar is installed).

### Dependencies

You can create targets that depend on other targets being run first.
For example, add this to your existing Makefile:

```
all: task task2 time
	@echo All done, phew!
```

Run `make all`, and it will run all three tasks in series: task,
task2, and time, and finally perform its own task:

```
$ make all
hi this is the task.
hello ryan this is another task.
I can have multiple lines
The current time is Wed Nov 16 07:12:36 PM PST 2022
All done, phew!
```

### Running make within make

Like dependencies, which run before your target, sometimes you'll want
to run other make targets *after* you do something else. AFAIK, there
is no way to do this in Make, except by calling `make` again.

What happens when you call make from make? Consider this Makefile

```
time:
	@echo The current time is $$(date)
inception:
	@echo Yo dawg.
	make time
```

Run :

```
$ make inception
Yo dawg.
make time
make[1]: Entering directory '/home/ryan/t'
The current time is Wed Nov 16 07:16:50 PM PST 2022
make[1]: Leaving directory '/home/ryan/t'
```

So it ran make twice, the second time as a child process of the first.
Theres a bit of noise here though. As it enters the second process, it
prints the text `make[1]: Entering directory '/home/ryan/t'` and when
its done it prints `make[1]: Leaving directory '/home/ryan/t'`. Unless
I'm debugging something this is just noise, so I change the target to
not print it:

```
inception:
	@echo Yo dawg.
	@make --no-print-directory time
```

## Main d.rymcg.tech Makefile

There is a [Makefile](Makefile) in the root directory of d.rymcg.tech.
Let's check out what it does using the help feature:

```
$ cd ~/git/vendor/enigmacurry/d.rymcg.tech
$ make help
Main Makefile help :
make help           - Show this help screen
make config         - Configure main variables
make build          - build all container images
make open           - Open the repository website README
make status         - Check status of all sub-projects
make backup-env     - Make an encrypted backup of the .env files
make restore-env    - Restore .env files from encrypted backup
make clean          - Remove all private files (.env and passwords.json files)
make show-ports     - Show open ports on the docker server
make audit          - Audit container permissions and capabilities
```

### make config

d.rymcg.tech needs to be configured once per Docker context to create
the file `.env_${DOCKER_CONTEXT}`. You can see all your Docker
contexts by running `docker context ls`. Your current context is
indicated by an asterisk `*`. For example, my current docker context
is named `ssh.t.rymcg.tech`, so the config file is named
`.env_ssh.t.rymcg.tech` and written in the root project directory:

```
$ make config
_scripts/check_deps docker sed awk xargs openssl htpasswd jq
Looking for docker ... found /usr/bin/docker
Looking for sed ... found /usr/bin/sed
Looking for awk ... found /usr/bin/awk
Looking for xargs ... found /usr/bin/xargs
Looking for openssl ... found /usr/bin/openssl
Looking for htpasswd ... found /usr/bin/htpasswd
Looking for jq ... found /usr/bin/jq
Docker is running.

This will make a configuration for the current docker context (ssh.t.rymcg.tech). Proceed? (Y/n): y
ROOT_DOMAIN: Enter the root domain for this context (eg. d.example.com)
: t.rymcg.tech
Configured .env_ssh.t.rymcg.tech
```

`make config` checks to see if it can find all the required tools, and
asks you to confirm the current docker context is correct, and to
enter a default `ROOT_DOMAIN` variable, which is saved to
`.env_${DOCKER_CONTEXT}`. The `ROOT_DOMAIN` is used in the sub-project
Makefiles to provide defaults to their own `make config`.

### make build

Many of the projects contained in d.rymcg.tech do not use images from
a Docker registry, but are instead built directly from Dockerfiles.
This happens automatically whenever you run `make install` in a
subproject directory. However, you may wish to build all of the images
in advance (they are stored in your server cache), and that is what
the root `make build` target is for. 

```
## Note this may take a long time to run!
## Recursively find all the projects docker-compose.yaml and build all images:
make build
```

### make open

This is a simple shortcut to open the main README in your web-browser.

### make status

`make status` will invoke `docker compose ls` and print all of the
running services managed by d.rymcg.tech and show the config location.

### make backup-env

`make backup-env` will find all of the environment files and
passwords.json files, and make an encrypted backup file, encrypted
with your offsite GNU Privacy Guard (GPG) public key.

### make restore-env

`make restore-env` will restore environment files and passwords.json
files from an encrypted backup file.

### make clean

`make clean` will delete all environment files and passwords.json
files recursively, including all project sub directories.

### make show-ports

`make show-ports` will help you find which containers are publicly
accessible by open ports.

```
$ make show-ports
Found these containers with open ports:
sftp-sftp-1     0.0.0.0:2223->2000/tcp, :::2223->2000/tcp
syncthing       127.0.0.1:8384->8384/tcp, 0.0.0.0:21027->21027/udp, :::21027->21027/udp, 22000/udp, 0.0.0.0:22000->22000/tcp, :::22000->22000/tcp
bitwarden       3012/tcp, 127.0.0.1:8888->80/tcp
Found these containers using the host network (so they could be publishing any port):
traefik-traefik-1
```

For example, these open ports are listed above:

  * `sftp-sftp-1` is listening on port `2223` publicly.
  * `syncthing` is listening on port `8384` on the Docker server
    localhost, and on port `21027` and `22000` publicly for both tcp
    and udp.
  * `bitwarden` is listening on port `3012` only on the private
    container address, and on port `8888` on the Docker server
    localhost
  * At the very bottom it found that `traefik-traefik-1` was
    configured with the Host network. Binding a container to the host
    means that it could be opening any port it wants, and docker won't
    know. You can find the entrypoints for Traefik listed in the
    [static configuration template](traefik/config/traefik.yml) and
    the values in the environment file
    (`TRAEFIK_WEB_ENTRYPOINT_PORT`,`TRAEFIK_WEBSECURE_ENTRYPOINT_PORT`,`TRAEFIK_MQTT_ENTRYPOINT_PORT`,`TRAEFIK_SSH_ENTRYPOINT_PORT`
    and possibly others).

### make audit

`make audit` will find all services, and print a report of the
privileges each service has, containing the following information:

 * `CONTAINER` the container name
 * `USER` the user and or UID the container runs as
 * `CAP_ADD` which system [capabilities](https://man.archlinux.org/man/capabilities.7) to add
 * `CAP_DROP` which system [capabilities](https://man.archlinux.org/man/capabilities.7) to drop
 * `SEC_OPT` which security options to enable.
 * `BIND_MOUNTS` the list of all bind (host) mounted paths.
 * `PORTS` the list of open ports.

```
$ make audit
CONTAINER                        USER         CAP_ADD                                                                         CAP_DROP  SEC_OPT                     BIND_MOUNTS                                                            PORTS
bitwarden                        root          __                                                                              __       ["no-new-privileges:true"]  []                                                                     {"80/tcp":[{"HostIp":"127.0.0.1","HostPort":"8888"}]}
cryptpad                         root          __                                                                              __       ["no-new-privileges:true"]  ["/etc/localtime:/etc/localtime:ro","/etc/timezone:/etc/timezone:ro"]  {}
debian                           root          __                                                                              __        __                         ["shell-shared:/shared"]                                               {}
drawio-drawio-1                  root          __                                                                              __       ["no-new-privileges:true"]  []                                                                     {}
sftp-sftp-1                      root         ["CHOWN","DAC_OVERRIDE","SYS_CHROOT","AUDIT_WRITE","SETGID","SETUID","FOWNER"]  ["ALL"]   ["no-new-privileges:true"]  []                                                                     {"2000/tcp":[{"HostIp":"","HostPort":"2223"}]}
syncthing                        root          __                                                                              __       ["no-new-privileges:true"]  []                                                                     {"21027/udp":[{"HostIp":"","HostPort":"21027"}],"22000/tcp":[{"HostIp":"","HostPort":"22000"}],"8384/tcp":[{"HostIp":"127.0.0.1","HostPort":"8384"}]}
thttpd-thttpd-1                  54321:54321   __                                                                              __       ["no-new-privileges:true"]  []                                                                     {}
traefik-traefik-1                traefik      ["NET_BIND_SERVICE"]                                                            ["ALL"]    __                         ["/var/run/docker.sock:/var/run/docker.sock:ro"]                       {}
websocketd-app-1                 root          __                                                                              __       ["no-new-privileges:true"]  []                                                                     {}
whoami_foo-whoami-1              54321:54321   __                                                                             ["ALL"]   ["no-new-privileges:true"]  []                                                                     {}
whoami-whoami-1                  54321:54321   __                                                                             ["ALL"]   ["no-new-privileges:true"]  []                                                                     {}
```

All well behaved process should:

 * Not run as root (if it can be avoided)
 * Only add the specific capabilites it needs.
 * Drop `ALL` other capabilites.
 * Set "no-new-privileges:true" Security Option. (Assuming it does not
   need to assume new privileges via `setcap` or `setuid` binary).

## Subproject Makefiles in d.rymcg.tech

There is a `Makefile` contained in every sub-project directory of
d.rymcg.tech. Each Makefile is different and customized for the
sub-project, but contains some baseline commands that are (usually)
the same:

```
$ cd ~/git/vendor/enigmacurry/d.rymcg.tech/whoami
$ make help
Makefile help for /home/ryan/git/vendor/enigmacurry/d.rymcg.tech/whoami:
make install        - (re)builds images and (re)starts services (only if changed)
make uninstall      - Remove service containers, leaving the volumes intact
make reinstall      - Remove service containers, and re-install (volumes left intact).
make config         - Configure .env file
make start          - Start services
make stop           - Stops services
make restart        - Restart services
make destroy        - Deletes containers AND data volumes
make ps             - Show containers status (docker compose ps)
make status         - Show status of all instances
make logs           - Tail all containers logs (set SERVICE=name to filter for one)
make open           - Open the web-browser to the service URL
make instance       - Create a duplicate instance with a copy of the current .env file
make switch         - Switch the default instance and enter a new subshell
make clean          - Remove current context/instance environment file and saved passwords.json
make clean-all      - Remove all environment files and saved passwords.json
```


### make config

Run `make config` to automatically create the configuration file
`.env_${DOCKER_COMPOSE}` and run a wizard to ask you questions to
interactively input answers to fill in the variables in the
configuration file. The wizard prefills default answers for you from
the provided `.env-dist` template.


```
$ cd ~/git/vendor/enigmacurry/d.rymcg.tech/whoami
$ make config
Configuring environment file: .env_ssh.t.rymcg.tech
WHOAMI_TRAEFIK_HOST: Enter the whoami domain name (eg. whoami.example.com)
: whoami.t.rymcg.tech
WHOAMI_NAME: Enter a unique name to display in all responses
: whoami
Set WHOAMI_INSTANCE=default
```

### make install

Run `make install` to build and install the service to the Docker
server (this runs `docker compose build` and `docker compose up` for
you):

```
$ cd ~/git/vendor/enigmacurry/d.rymcg.tech/whoami
$ make install
ENV_FILE=.env_ssh.t.rymcg.tech
# docker compose -f docker-compose.yaml --env-file=.env_ssh.t.rymcg.tech --project-name=whoami build 
ENV_FILE=.env_ssh.t.rymcg.tech
# docker compose -f docker-compose.yaml --env-file=.env_ssh.t.rymcg.tech --project-name=whoami up -d
[+] Running 2/2
 ⠿ Network whoami_default     Created                                              0.1s
 ⠿ Container whoami-whoami-1  Started                                              0.7s
```

### make uninstall

Run `make uninstall` to remove services that are installed. This will
leave the volumes intact, so you can run `make install` again and the
old data will still be available.

### make reinstall

`make reinstall` is an alias for `make uninstall install`, whereas
`make install` will only restart containers as necessary, `make
reinstall` forces the shutdown and restart of containers.

### make start

`make start` will start the services without building the image first.

### make stop

`make stop` will stop the services, but leave the containers and images intact.

### make restart

`make restart` is an alias for `make stop start`

### make destroy

`make destroy` will confirm you wish to delete the containers and
volumes, and then do it.

### make ps

`make ps` will show a list of the deployed containers for the current
instance only.

```
$ make ps
Showing containers for a single instance (use `make status` to see all instances.)
ENV_FILE=.env_ssh.t.rymcg.tech
# docker compose -f docker-compose.yaml --env-file=.env_ssh.t.rymcg.tech --project-name=whoami ps -a
NAME                COMMAND                  SERVICE             STATUS              PORTS
whoami-whoami-1     "/whoami --port 8000…"   whoami              running             80/tcp
```

### make status

`make status` will show a list of all instances:


```
$ make status
NAME                 ENV                        ID          IMAGE           STATE    PORTS
whoami-whoami-1      .env_ssh.t.rymcg.tech      485ef4d401  traefik/whoami  running  {"80/tcp":null}
whoami_foo-whoami-1  .env_ssh.t.rymcg.tech_foo  e25a25bcb5  traefik/whoami  running  {"80/tcp":null}
```

### make logs

`make logs` will show the logs for the current instance services:

```
$ make logs
ENV_FILE=.env_ssh.t.rymcg.tech
# docker compose -f docker-compose.yaml --env-file=.env_ssh.t.rymcg.tech --project-name=whoami logs -f 
whoami-whoami-1  | 2022/11/17 01:28:12 Starting up on port 8000
whoami-whoami-1  | 2022/11/17 01:32:57 Starting up on port 8000
```

### make open

`make open` will open the subproject URL in your web browser.

### make instance

`make instance` will create a new environment file with an appended
instance name: `.env_${DOCKER_CONTEXT}_${INSTANCE}`

```
$ make instance
Enter an instance name to create/edit: foo
+ cp .env-dist .env_ssh.t.rymcg.tech_foo
+ make --no-print-directory config INSTANCE=foo ENV_FILE=.env_ssh.t.rymcg.tech_foo
Configuring environment file: .env_ssh.t.rymcg.tech_foo
make -e --no-print-directory config-hook override instance=foo
WHOAMI_TRAEFIK_HOST: Enter the whoami domain name (eg. whoami.example.com)
: whoami-foo.t.rymcg.tech
WHOAMI_NAME: Enter a unique name to display in all responses
: foo
Set WHOAMI_INSTANCE=foo
```

### make switch

`make switch` will let you redefine the default instance name in a new
temporary subshell:

```
$ make switch
Enter the temporary default instance name: foo

(instance=foo)
whoami $ make config
make[1]: Entering directory '/home/ryan/git/vendor/enigmacurry/d.rymcg.tech/whoami'
Configuring environment file: .env_ssh.t.rymcg.tech_foo
make -e --no-print-directory config-hook override instance=foo
WHOAMI_TRAEFIK_HOST: Enter the whoami domain name (eg. whoami.example.com)
: whoami-foo.t.rymcg.tech
WHOAMI_NAME: Enter a unique name to display in all responses
: foo
Set WHOAMI_INSTANCE=foo
make[1]: Leaving directory '/home/ryan/git/vendor/enigmacurry/d.rymcg.tech/whoami'

(instance=foo)
whoami $ 
```

For as long as you leave the new subshell open, all make targets will
affect the `foo` instance (or whaver name you chose.). Run `exit` or
press `Ctrl-D` to quit the subshell.

### make clean

`make clean` will remove the environment file and saved passwords for
the current docker context and/or instance.

```
$ make clean
$ make clean instance=foo
```

### make clean-all

`make clean-all` will remove all of the environment files and saved
passwords.json for all docker contexts.
