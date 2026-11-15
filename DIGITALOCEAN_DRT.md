# DigitalOcean with drt

This guide sets up a Docker server on [DigitalOcean](https://www.digitalocean.com/) and manages it from [drt](WORKSTATION_CONTAINER.md), the d.rymcg.tech workstation container. The only software it needs on your workstation is bash and Podman.

The drt shell is ephemeral. Its only persistent state is one encrypted config file per context: drt decrypts it when a session starts and offers to save your changes back when you exit. Keep two things safe: that file and the AGE key that unlocks it.

The guide uses gumdrop's quick start (`d droplet quick`) to create the droplet, DNS records, Traefik and a wildcard TLS certificate in one step. To do each step by hand, see [DIGITALOCEAN.md](DIGITALOCEAN.md).

## What you need

- A Linux workstation with bash and Podman.
- An SSH key loaded in your host's ssh-agent. drt forwards the agent into the container, and the public key will go onto the droplet you'll create.
- A DigitalOcean account and a [personal access token](https://docs.digitalocean.com/reference/api/create-personal-access-token/) with read and write scope.
- A domain name managed by DigitalOcean DNS in the same team, so `drt` can create its records. If it isn't there yet, add it in the DigitalOcean control panel under **Networking → Domains**, then point your registrar at DigitalOcean's nameservers.

## Install Podman and pull the image

Install Podman from your distribution's package manager ([instructions](https://podman.io/docs/installation)), then pull the drt image:

```bash
podman pull ghcr.io/enigmacurry/d-rymcg-tech:latest
```

This image has everything else you'll need, built in: the d.rymcg.tech repo, the Docker CLI, sops, age and doctl.

## Add drt to your shell

Add these lines to `~/.bashrc` (or `~/.zshrc`):

```bash
export DRT_IMAGE=ghcr.io/enigmacurry/d-rymcg-tech:latest
podman image exists "${DRT_IMAGE}" && source <(podman run --rm --pull=never --net=none \
  --entrypoint cat "${DRT_IMAGE}" /home/user/git/vendor/enigmacurry/d.rymcg.tech/_container/drt.bashrc)
```

The second line loads the `drt` shell function from inside the image, so drt always matches the image you pulled. You also get tab completion for your context names.

Open a new shell and check that it works:

```bash
drt --version
```

It prints a short git SHA, such as `drt caa5b5c91d09`: the commit the image was built from. It matches a tag on the [image's registry page](https://github.com/EnigmaCurry/d.rymcg.tech/pkgs/container/d-rymcg-tech).

## Create a context

A context is one server plus everything you deploy to it. Create one called `foo`:

```bash
drt --init foo
```

The name you choose will be the name of the Docker context, SSH host alias, and the Droplet you'll use later. The wizard asks two things:

1. **AGE key protection.** Choose *Passphrase protected key file*. The key file alone can't decrypt anything, and you'll type the passphrase each time you start `drt`.
2. **Configure SSH connection to a Docker host now?** Answer **no**. The droplet doesn't exist yet; quick start will connect it for you.

When it finishes, `drt` lists what to back up: the AGE key at `~/.config/d.rymcg.tech/keys/sops/foo.key`, its passphrase, and the encrypted config at `~/.config/d.rymcg.tech/config/foo.sops.env`. Lose the key or the passphrase and the config can't be decrypted.

## Start a session

Start a session in the new context:

```bash
drt foo
```

Enter your AGE passphrase, and you land in a shell inside the container. The prompt shows `local` instead of `foo` for now, because the context isn't connected to a server yet.

## Build the server with quick start

gumdrop, the built-in DigitalOcean manager, can build the whole server in one go:

```bash
d droplet quick
```

(You can also run `d droplet` and choose **Quick start** from the main menu.)

The first time, gumdrop tells you `doctl` isn't authenticated and offers to log in. Say yes, give the account a name (the default is `default`), and paste your personal access token.

Quick start then asks every question up front. In these examples your domain is `example.com`; these answers give you a small Docker server ready for web apps:

| Prompt | Answer |
| --- | --- |
| Droplet name | `foo`, the default (your context's name) |
| Select region | the one closest to you |
| Select size | the default, `s-2vcpu-4gb` |
| Select image | the default, `debian-13-x64` |
| Which SSH key should log in to the droplet? | the key marked *in your ssh-agent*, or *Upload ssh-agent key* if it isn't on DigitalOcean yet |
| Firewall: allow SSH from | Anywhere |
| Assign a new reserved (static) IP address? | No |
| Enable DigitalOcean backups? | No |
| Which domain? | `example.com` |
| Subdomain for this server | `foo`, the default |
| TLS certificates | the default, **Wildcard via self-hosted acme-dns** |
| Let's Encrypt environment | Production |
| Email address for Let's Encrypt notices | optional |
| Default timezone for containers | yours |
| Install whoami as a test app? | Yes |

Every app you install later gets its own name under the subdomain, such as `whoami.foo.example.com`. The TLS default gets one wildcard certificate for `*.foo.example.com` that covers all of them, through [acme-dns](acme-dns) running on the droplet itself. The DigitalOcean token stays in your drt session and never goes onto the server.

Check the summary, then confirm. From here quick start runs unattended, and it asks nothing else:

1. Creates a firewall and the droplet, with a cloud-init that installs Docker.
2. Creates the DNS records: `foo` and `*.foo`, plus the records acme-dns needs.
3. Waits for SSH, and for cloud-init to finish installing Docker.
4. Connects the `foo` context to the droplet over SSH.
5. Sets the context's root domain to `foo.example.com`.
6. Installs acme-dns and Traefik, and requests the wildcard certificate.
7. Installs `whoami`, and waits until `https://whoami.foo.example.com` answers with a valid certificate.

It takes several minutes, mostly waiting for cloud-init and for the certificates. When it finishes, open `https://whoami.foo.example.com` in your browser.

If a step fails, run `d droplet quick` again with the same droplet name. It offers to resume setup on the existing droplet, skipping the droplet questions.

## Exit and save

The container is ephemeral. Everything quick start did inside it, including the doctl login and the connection to the droplet, exists only in the container's own filesystem and disappears when it stops. The question `drt` asks when you exit is the only thing that writes your choices back to the encrypted config.

Type `exit`. `drt` compares your session with the saved config, shows a diff, and asks:

```
## Configuration changes detected:
...
+## SSH
+SSH_HOST=203.0.113.10
+SSH_USER=root
...
+## doctl config
+__doctl_config__=H4sI...
...
Save changes to /home/user/.config/d.rymcg.tech/foo.sops.env? [Y/n]
```

Answer **Y**. `drt` re-encrypts `foo.sops.env` with your changes: the droplet's address and host key, the Traefik, acme-dns and whoami configs, and your doctl login. Answer **n** and the session is thrown away, as if it never happened. The droplet keeps running, but the `foo` context won't know about it.

Don't share or screenshot that diff. The `__…__=` values are only compressed and base64-encoded, not encrypted, and the doctl entry holds your DigitalOcean token.

## Check the connection

Start a session again:

```bash
drt foo
```

The prompt now shows `foo`, and `drt` creates a Docker context named `foo` that talks to the droplet over SSH. Check it:

```bash
docker info | grep Name
```

It prints the droplet's host name. From now on, every `docker` and `d` command in this shell runs against the droplet.

## Where next

You now have a Docker server on DigitalOcean, with DNS, Traefik and a wildcard certificate already in place, and a `drt foo` session that reaches it. Install more apps with the [d.rymcg.tech tour](TOUR.md), skipping its root config, Traefik and acme-dns steps, since quick start did those. Remember to answer **Y** when you exit, so your app configs are saved too.

For more of what gumdrop can do, such as volumes, snapshots, backups and reserved IPs, see [DIGITALOCEAN.md](DIGITALOCEAN.md).
