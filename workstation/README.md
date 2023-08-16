# Container Workstation Service

This container is used to control your native Docker instance from
within Docker itself (Docker *in* Docker). It includes the Bash shell,
all of the docker command line tools, and can be used as a full
workstation for
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech).

This container runs the OpenSSH service on port 2222 (by default).
This port is mapped publicly to the external network of the Docker
server, so any authorized user can SSH into your workstation
container, from anywhere accessible on the public network, and it
*requires* SSH key-based authentication.

*Warning*: this is a privileged container and it directly mounts the
Docker socket of the host `/var/run/docker.sock` into this container.
. This means that the container workstation has full root control over
the host machine. This should be treated as a secure developer
workstation, running trusted software, but it is only as secure as you
keep your client SSH keys secure. Always remember that you should
exclusively install Docker Engine on dedicated machines, whether bare
metal or in a Virtual Machine. *Never* install Docker Engine natively
on a workstation/laptop, otherwise you risk exposing private user
files.

## Configure

On your existing d.rymcg.tech workstation (ie. native computer),
configure the default container workstation instance:

```
# This configures the 'default' instance:
make config
```

You can only create one `default` instance, so if you wish to run more
than one container workstation, you can create several named
instances:

```
# This creates the named workstation instance 'foo':
make instance
```

Please read the [`d.rymcg.tech` README chapter on
instances](https://github.com/EnigmaCurry/d.rymcg.tech/#creating-multiple-instances-of-a-service)
for more information.

## Install

```
make install
```

## Configure the client

From any native workstation computer, where you want to connect to
your container workstation over SSH, do the following:

 * Create a new SSH config entry for your container workstation, in
`~/.ssh/config`, for example:

```
## put this in your CLIENT ~/.ssh/config file.
Host workstation-m1-default
     Hostname ssh.d.example.com
     Port 2222
     User ryan
     ControlMaster auto
     ControlPersist yes
     ControlPath /tmp/ssh-%u-%r@%h:%p
```

In the example config above, change the following:

   * `workstation-m1-default` is an SSH alias for my container
     workstation, you can make this whatever name you want, but the
     example uses the default naming convention of the container:: `m1`
     is the name of my Docker host, and `default` is the name of my
     workstation instance.
   * `ssh.d.example.com` is the actual hostname of the Docker machine,
     it must have a DNS entry that resolves to the IP address of the
     Docker machine.
   * `2222` is the external/public SSH port I chose for the container
     with `make config` (`WORKSTATION_PUBLIC_SSH_PORT`).
   * `ryan` is the username I chose for the container with `make config`
     (`WORKSTATION_USER`).
   * The `ControlMaster`, `ControlPersist`, and `ControlPath` setup SSH
     connection sharing and speeds up the time it takes to (re)connect
     to the SSH server.

 * Make sure you have an SSH key created for your client. Your SSH key
is most likely stored in `~/.ssh/id_rsa`, but if you don't have one
yet, run `ssh-keygen` to create one.

Copy your client *public* SSH key to your clipboard:

```
## If you didn't use the default ssh-keygen parameters,
## this might not be the correct path, but it usually is:

cat ~/.ssh/id_rsa.pub
```

The output of that command should contain a single long line of text,
starting with `ssh-rsa AAAA...` and ending with `= <user>@<client
host>`. This is your *client's* SSH public key. To validate your
connection, you need to tell the container workstation to trust this
key, which you'll do in the next step...

## Configure SSH authentication

The SSH service *requires* SSH key-based authentication, and by
default, no keys are installed. So you will need to install your
client SSH key before you connect the first time. You can "exec"
directly into the container shell to do so:

```
## From your native d.rymcg.tech workstation, 
## 'docker exec' into the container shell:
make shell
```

This will attach your terminal to the Bash shell of the container
workstation, and from inside this subshell, you may add your SSH
public key to the `~/.ssh/authorized_keys` file in the container,
which there are a few different ways of doing this:

```
# If you are already setup on GitHub with the same SSH keys you want to use:
### (Change 'enigmacurry' to your own GitHub username):
### GitHub shares your public keys publically, so this copies directly from github: 
ssh-import-id gh:enigmacurry

# Otherwise, you need to manually add your key to ~/.ssh/authorized_keys:
# Run this with your entire long SSH public key in place of AAAA.....
echo "ssh-rsa AAAA....." >> ~/.ssh/authorized_keys
```

Once you've added the key, exit the shell with Ctrl-D or type `exit`
and press Enter.

Now that you have your SSH client configured, and your public key
installed in the container workstation `~/.ssh/authorized_keys` file,
you can now connect from your client:

```
# Use your own SSH alias to connect:
ssh workstation-m1-default
```

You should now be authenticated and connected to the container
workstation.

The first time that you connect, all of the `d.rymcg.tech`
dependencies will be automatically installed, including all of the
`docker` command line utilities. This is done only the first time you
login, and it is to minimize the size of the base container image, and
to ensure that you get up-to-date tools and source code.

When its all done installing you should be put into the Bash shell of
the container workstation, and see the prompt:

```
ryan@workstation-m1-default:~$ 
```

(Of course you should see your own chosen username, docker hostname,
and instance names)