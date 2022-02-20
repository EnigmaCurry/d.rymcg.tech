# d.rymcg.tech in brief

`d.rymcg.tech` is a collection of applications that you can self-host with
Docker. Using your own domain name, you can host public HTTP and TCP services,
as well as private services from clients connected to a VPN.

See [README.md](README.md) for the full winded description.

## Requirements

This part's on you:

 * Provision a Linux server, setup external firewall, configure SSH, install
   Docker.
 * Create DNS `A` records for all of the domains that you will use, and point
   them to your server's IP address. This can be a wildcard record like
   `*.d.example.com` (where `d` is any name you like, uniquely identifying this
   installation, or you can forgo that and use `*.example.com` if you prefer to
   dedicate the entire domain for this purpose.)
 * Setup a Linux-ish workstation, configure key based SSH access to the server,
   setup the remote Docker context to use Docker over SSH, test `docker run
   hello-world` works. Install `make`, `docker-compose`, `jq`, `apache2-utils`,
   `xdg-utils`, and `wireguard`.

## Do everything from your workstation

```
GIT_SRC=~/git/d.example.com

git clone https://github.com/EnigmaCurry/d.rymcg.tech.git ${GIT_SRC}
cd ${GIT_SRC}
```

Make the root config:

```
make config
```

(This may list some missing dependencies, if so, install the missing packages
and try `make config` again.)

Install Traefik:

```
cd ${GIT_SRC}/traefik
make config
make install
```

Install whoami:

```
cd ${GIT_SRC}/whoami
make config
make install
```

Open the whoami page in your browser (utilizes `xdg-open` to open the browser
automatically):

```
make open
```

This same pattern applies for all of the other projects you can install:

 * `make config` creates the `.env` file, which is the application config file.
 * `make install` runs `docker-compose` to bring up your application, applying
your `.env` file as config.
 * `make open` opens the application URL in your browser.

Each project directory has its own `Makefile`, so try running `make help` in
each directory, and you will see a project specific help screen with all of the
targets (commands) for that project. Some projects have some extra maintainance
targets you can run. Always check the `README.md` found in each sub-project
directory.

## Setup the VPN

If you want private services, setup the VPN server and client:

```
cd ${GIT_SRC}/wireguard
make config
make install
```

Connect to the VPN from your workstation:

```
make client-install
make client-start
```

Install the private whoami server:

```
cd ${GIT_SRC}/wireguard/whoami
make config
make install
```

Open the private whoami page in your browser:

```
make open
```
