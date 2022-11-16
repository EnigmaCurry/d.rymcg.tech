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
file](#overriding-docker-composeyaml-per-instance). The override is
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
