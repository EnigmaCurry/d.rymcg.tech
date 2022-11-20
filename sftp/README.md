# sftp (OpenSSH)

This is a security hardened configuration of
[OpenSSH](https://www.openssh.com/) setup exclusively as an SFTP
server. Multiple chrooted user accounts are created, according to your
environment file, allowing login with public key auth only, and this
gives protected external file transfer to/from any of your Docker
volumes.

## Security

OpenSSH has been hardened in the following ways:

 * [sshd_config](sshd_config) has been configured to:
   * Use only v2 protocol with ed25519 or RSA key types.
   * Require pubkey authentication exclusively (`PubkeyAuthentication
     yes` and `PasswordAuthentication no`).
   * Only serve SFTP with the `internal-sftp` server.
   * Disable the shell, port forwading, and X11 forwarding.
   * Per-user account chroot (`ChrootDirectory`). Each user can only
     see their own files.
 * In order to use the `ChrootDirectory` config directive, `sshd` [must run as root to access chroot(2)](https://github.com/openssh/openssh-portable/blob/25bd659cc72268f2858c5415740c442ee950049f/session.c#L1431-L1434) (even if you give it the `CAP_SYS_CHROOT` capability via setcap, an unpatched sshd will still refuse to allow chroot(2) [unless UID==0 explicitly](https://github.com/openssh/openssh-portable/blob/2923d026e55998133c0f6e5186dca2a3c0fa5ff5/platform.c#L82-L92); so a non-root user would be unable to run `sshd` with the `ChrootDirectory` directive). To limit the permissions of the root user, the Docker container drops all of the unnecessary [Linux system capabilities](https://man.archlinux.org/man/capabilities.7), except for the following list that are still required (tested by process of elimination):

```
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SYS_CHROOT
      - AUDIT_WRITE
      - SETGID
      - SETUID
      - FOWNER
```

 * All config files and keys are made immutable by a secondary config
   container, by temporarily giving it the `LINUX_IMMUTABLE`
   capability. This capability is dropped by the main `sftp`
   container, such that these files are made completely unmodifiable,
   even by the root user. Every time you run `make install` the keys
   and config files are temporarily made mutable, then reconfigured
   according to your environment, and then relocked again before
   starting `sftp`.

## Volumes

Each instance of `sftp` may configure its own custom list of external
Docker volumes to mount (`SFTP_VOLUMES`). This utilizes a
[docker-compose override
file](../README.md#overriding-docker-composeyaml-per-instance). The override is
created automatically from the override template:
[docker-compose.instance.yaml](docker-compose.instance.yaml). The
generated override file
(`docker-compose.override_${DOCKER_CONTEXT}.yaml`) is created
automatically whenever you run `make config` based upon the
`SFTP_VOLUMES` environment variable (the override file should not be
hand edited). When you run `make install`, the base configuration
[docker-compose.yaml](docker-compose.yaml) is merged with the
generated override file, to compose the full configuration.

If `SFTP_VOLUMES` is not used (ie. blank) then the `sftp` instance
will not mount any external volumes, and will only use the internal
volumes specified by the base configuration
([docker-compose.yaml](docker-compose.yaml)): `sftp_config` and
`sftp_data` (or the custom-instance volumes: `sftp_${INSTANCE}_config`
and `sftp_${INSTANCE}_data`).

The volume mount points are :

 * `sftp_ssh-config` mounted to `/etc/ssh` as root, containing all the
   configuration, private keys, and authorized public keys.
 * `sftp_ssh_data` mounted to `/data`. Under this directory, each user
   is given their own unique chroot that is owned by root, for
   example:

   * `/data/bob-chroot` (owned by root)
   * `/data/alice-chroot` (owned by root)

 * `/data/${USER}-chroot` directory must be owned by root in order for
   the sshd_config `ChrootDirectory` directive to work. Each user is
   given permission to write to a subdirectory with their own name,
   for example:

   * `/data/bob-chroot/bob` (owned by bob, backed by the default
     `sftp_data` volume)
   * `/data/alice-chroot/alice` (owned by alice, backed by the default
     `sftp_data` volume)

 * If `SFTP_VOLUMES` is specified, extra external volumes are mounted
   in addition, for example if
   `SFTP_VOLUMES=some_volume:bob:stuff,other_volume:alice:misc`, then
   the following extra directories are created/mounted:

   * `/data/bob-chroot/bob/stuff`
   * `/data/alice-chroot/alice/misc`

 * When each user logs in, they are placed in a chroot with only their
   own files visible:

   * Bob only sees: `/bob` and `/bob/stuff`.
   * Alice only sees: `/alice` and `/alice/misc`.

## Config

Run:

```
make config
```

Answer the questions for these variables:

 * `SFTP_PORT` This is the publicly exposed TCP port of the SFTP
   server. (Note: this port is directly mapped on the host, it does
   not flow through Traefik.)

```
SFTP_PORT=2223
```

 * `SFTP_USERS` This is a comma separated list of user:UID pairs to
   create SFTP accounts. Match the UID to the same UID that your data
   (or service container) uses (see example below). If you only use
   the default sftp volume (without any other consumers of the
   volume), then the UIDs may be arbitrarily chosen but should be
   unique.

```
## For example, to create two accounts, ryan (UID=54321) and gary (UID=1001):
SFTP_USERS=ryan:54321,gary:1001
```

 * `SFTP_VOLUMES` This is a comma separated list of volume:user:mount
   3-tuples, to configure the external volumes and user mountpoints.
   These volumes should already exist before starting `sftp`. If you
   only use the default sftp volume, then `SFTP_VOLUMES` may be left
   blank. The order of the items of the 3-tuple are: 1) `volume` - the
   name of the Docker volume, 2) `user` - the SFTP user account name,
   3) `mount` the name for the mountpoint in the container (this can
   be arbitrary, but should be recognizable to the SFTP user.)

```
## For example, to mount two volumes: thttpd_files and music_stuff
## Volume `thttpd_files` will mount to /data/ryan-chroot/ryan/web
## Volume `music_stuff` will mount to /data/gary-chroot/gary/music
SFTP_VOLUMES=thttpd_files:ryan:web,music_stuff:gary:music
```

## Example

This example will create the following services:

 * [thttpd](../thttpd) - A static HTTP websever served with HTML files
   stored in a volume.
 * `sftp` setup to share the thttp volume, and create an SFTP user
   account to manage uploading new files.

First, it is assumed that you have already followed the [main
d.rymcg.tech README](../README.md) and have setup
[Traefik](../traefik/README.md) on your Docker server.

### Install thttpd

Start by deploying the [thttpd](../thttpd) webserver:

```
cd ~/git/vendor/enigmacurry/d.rymcg.tech/thttpd
make config
make install
```

Respond to the question for `THTTPD_TRAEFIK_HOST`, and set the domain
name for the webserver (eg. `www.example.com`). Notice in the .env
file it sets the following without asking:

```
## These are the UID and GID of the thttpd webserver and all its files:
THTTPD_UID=54321
THTTPD_GID=54321
```

Once its deployed, you should be able to see the `Hello World!`
message by visiting the URL for the server (eg. `www.example.com`).

### Install sftp

```
cd ~/git/vendor/enigmacurry/d.rymcg.tech/sftp
make config
```

Answer the question for `SFTP_USERS`, you can choose an arbitrary
username, but be mindful to choose the same UID that `thttpd` uses:

```
ryan:54321
```

Answer the question for `SFTP_VOLUMES`, the default volume for thttpd
is `thttpd_files`, enter the same username as you chose in
`SFTP_USERS`, and any mountpoiint name you wish (all joined with `:`):

```
thttpd_files:ryan:web
```

This will have configured two files:

 * `.env_${DOCKER_CONTEXT}` containing the environment variables.
 * `docker-compose.override_${DOCKER_CONTEXT}.yaml` containing the
   customizied volume mounts. (this is generated by the
   [ytt](https://carvel.dev/ytt/docs/latest/) template
   [docker-compose.instance.yaml](docker-compose.instance.yaml))

Now you can install `sftp`:

```
## Still in the sftp directory:
make install
```

The override configuration is merged with the base template
[docker-compose.yaml](docker-compose.yaml) automatically.

Check that the service has started properly:

```
$ make logs
...
sftp-sftp-1  | Server listening on 0.0.0.0 port 2000.
sftp-sftp-1  | Server listening on :: port 2000.
^C

$ make status
NAME         ENV                    ID          IMAGE      STATE    PORTS
sftp-sftp-1  .env_ssh.t.rymcg.tech  ad388ba4f6  sftp-sftp  running  {"2000/tcp":[{"HostIp":"0.0.0.0","HostPort":"2223"},{"HostIp":"::","HostPort":"2223"}]}
```


## Add SSH identities and test login

You won't be able to login to the SFTP server until you add SSH public
keys for the accounts. This is handled as a separate manual process,
to be performed after `sftp` is running.

You can easily add your own local workstation public keys to any
existing SFTP user account (`SFTP_USERS`):

```
make ssh-copy-id
```

This will prompt you to enter an SFTP user account, and then your
local workstation keys are queried from your running SSH agent
(`ssh-add -L`) and copied to the SFTP server authorized_keys file.

You can also bypass the wizard by inputting the username on the command line:

```
make ssh-copy-id user=ryan
```

To import keys other than your local agent's, you can exec directly
into the container as root. Each user's authorized keyfile is named
like `/etc/ssh/keys/${USER}_authorized_keys`. This file is normally
locked and made immutable, and so you must first unlock the
authorized_keys file to make it mutable:

```
## a) Make files mutable, and
## b) Exec into the running sftp container as root, perform any changes, exit, and
## c) Make files immutable again:
make unlock-mutable-config shell lock-immutable-config

## Inside the container, you can run ssh-import-id to import from github, etc:
#ssh-import-id -o /etc/ssh/keys/ryan_authorized_keys gh:enigmacurry
```

Once the public keys are installed, you can test logging into the
server, using the correct port (`SFTP_PORT`) and username
(`SFTP_USERS`) (you can use any domain name that resolves to your
public server IP address):

```
sftp -P 2223 ryan@ssh.d.rymcg.tech
```


## Immutable config files (OR: A story about running an unprivileged sshd)

I started down the path of wanting to run sshd as an unprivileged
non-root user. [I found a good set of notes about that
here](https://www.golinuxcloud.com/run-sshd-as-non-root-user-without-sudo),
and heres a log of what I tried. For my purposes, I wanted to run
`sshd` rootless on a normal installation of Docker. Docker Engine, in
its default configuration, **runs as root**, and *by default* all
containers run as root as well. Docker does have a [User Namespace
mode]() and a [Rootless
mode](https://docs.docker.com/engine/security/rootless/) and there are
also implementations like Podman that can be run rootless, (any of
which let you map unused UID ranges to your containers, allowing the
appearance of root in the container, but it is to be mapped to some
non-root user UID on the host) but none of these options are under
consideration for this situation. Regretably, you cannot run a
container (traefik) in host networking mode, without also having real
root access, so default Docker is what we're stuck with.

My requirements, including nice-to-haves:

 * Must run on a default configured Docker server (Docker Engine
   running as root).
 * Must drop as many privileges as possible to limit attack surface.
 * To prevent abuse, the user must not be able to modify any of the
   SSH host keys, `/etc/ssh/sshd_config`, nor their own
   `authorized_keys` file. An admin is required to do these things.
   Bonus points if the user cannot even see these things.
 * Must allow at least one user to login with public key
   authentication only, and then transfer only their own files in/out
   of a preconfigured directory/volume permissioned for the user.
 * Nice to have: support multiple user logins and separate
   permissioned directories for each.
 * Nice to have: users should not see any files from any other users (chroot).
 * Nice to have: `sshd` should not run as root if it can be avoided.

The benefits of running sshd as non-root include:

 * If there is some vulnerability found in Linux, or Docker, to escape
   the container environment, and gain access to the host operating
   system, then an attacker will only inherit the user privileges that
   the container user (UID) was running as. If the container user is
   root (UID 0), then an attacker would gain the real host root (UID
   0) access as well. If the container user is non-root (eg. UID
   1000), then an attacker would only gain access to the same non-root
   UID (UID 1000) on the host (which may not even exist). This greatly
   limits any potential vulnerability.
 * Consider this: every application you install on Android (which runs
   on Linux) receives a unique user account, specifically to sandbox
   each app run based on the UID.

The drawbacks of running sshd as non-root include:

 * Without root access, the only user who can login through `sshd` is
   the same user that `sshd` runs as.
 * You cannot use the `ChrootDirective` as non-root (UID!=0). Although
   Linux has a
   [capability](https://man.archlinux.org/man/capabilities.7) to give
   non-root users access to `CAP_SYS_CHROOT`, and you can give the
   sshd binary access to this privilege by `setcap`, apparently sshd
   will not use the ability unless the UID==0. When you attempt to run
   this as any other UID, you will get the error "[server lacks
   privileges to chroot to
   ChrootDirectory](https://github.com/openssh/openssh-portable/blob/25bd659cc72268f2858c5415740c442ee950049f/session.c#L1431-L1434)"
   in the log, which fails due to the [uidswap check
   here](https://github.com/openssh/openssh-portable/blob/2923d026e55998133c0f6e5186dca2a3c0fa5ff5/platform.c#L82-L92)
   which explictly requires an effective UID of 0. This makes some
   sense considering that OpenSSH is not a Linux-native application,
   but must support a wider range of host operating systems and
   maintain secure defaults.
 * If sshd must run as the same user that is allowed access, and no
   chroot is allowed, then that would mean that the user has access to
   read or modify the private SSH host key (eg.
   `/etc/ssh/keys/ssh_host_rsa_key`) and also has access to modify the
   `/etc/ssh/sshd_config` file. Assuming you only deploy the service
   for one user, and you trust them not to abuse this, this is not so
   bad, but ideally the user should not be able to destroy their own
   account nor change keys.

The benefits of config and key file immutablity include:

 * The root user, or any user granted the `LINUX_IMMUTABLE`
   capability, can make files immutable by running `chattr +i FILE`.
   This prevents any user from modifying or deleting a file,
   regardless of the permissions and/or owner. Obviously this
   limitation does not affect the user with `LINUX_IMMUTABLE`
   capability, because this user can simply make the file mutable
   again by running `chattr -i FILE`.
 * To make it so that a process run as root (or another privileged
   user) cannot use `chattr +i` nor `chattr -i`, you must drop the
   `LINUX_IMMUTABLE` capability *before* running the intended task.
   Once a capability has been dropped, it cannot be re-acquired within
   the same process (nor its children; assuming
   `security_opt:['no-new-privileges:true']`), thus preventing even
   root from changing immutable files.

The drawbacks of config and key file immutablity include:

 * If the files are immutable, you can't change them, even if you want
   to. So in order to modify them, you need a secondary out-of-band
   method of unlocking and relocking the files, from a process that
   still retains the `LINUX_IMMUTABLE` capability.

So heres where I ended up:

 * Run `sshd` as root (UID=0) since its required to use
   `ChrootDirectory`.
 * Drop all capabilites except for the ones necessary to run chroot(2)
   and other stuff determined by process of elmination:
   * I tested this by dropping `ALL` privileges, and added back every
     single one explicitly, then tested if `sshd` works (it definitely
     should with every capability!) then I tried removing each
     capability and retesting if `sshd` still works. The final list of
     `cap_add` directives is the minimal set required:

```
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SYS_CHROOT
      - AUDIT_WRITE
      - SETGID
      - SETUID
      - FOWNER
```
 * Configure a separate [temporary
   container](https://github.com/EnigmaCurry/d.rymcg.tech/blob/f7e257c2611b9ed3b5b80ac20758c2362631009a/sftp/Makefile#L28-L36)
   to perform administrative tasks, and to unlock and relock the file
   immutability. This process is
   [granted](https://github.com/EnigmaCurry/d.rymcg.tech/blob/ecea0af2171518f104caf8856bb69d6cd068a6e1/sftp/docker-compose.yaml#L8-L18)
   the `LINUX_IMMUTABLE` capability in order to perform its tasks.
