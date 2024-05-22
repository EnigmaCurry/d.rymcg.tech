# Step-CA

[Step-CA](https://smallstep.com/docs/step-ca/) is a secure, online,
self-hosted Certificate Authority (CA). Its purpose is to issue (sign)
X.509 (TLS) certificates, and to securely store the private key for
the root CA.

## Config

```
make config
```

You must run step-ca interactively, for the first time only. This is important
because you need to make a record of the CA password, which is only
printed one time in the log:

```
# Run the step-ca interactively the first time only:
make up service=step-ca
```

In the log output, you should find your new password:

```
step-ca-1  | 👉 Your CA administrative password is: xxxxxxxxxxxxxxxxxxxxxxxxx
step-ca-1  | 🤫 This will only be displayed once.
```

> [!NOTE]
> If this is *not* the very first time you've tried running this, and
> you can't find the password in the log, and you want to start
> completely fresh, run `make destroy` before trying this again.

Once you have copied the password, and stored it in a safe place,
press `Ctrl-C`, and the service will automatically shutdown. You will
need this password for later when you request new certificates to be
created.

> [!NOTE] 
> Starting the container up one time, and then shutting it down, also
> served another purpose: on the first run, the Step-CA service
> automatically creates `/home/step/config/ca.json` (in the container
> volume), this is important to know the order in which it creates it,
> because our `config` container requires this file to already exist
> (it wants to modify an existing config file), and since its supposed
> to run *before* the step-ca container, we must run it manually, one
> time only. This ensures that `ca.json` now exists in the config
> volume, and now the `config` container can fully manage this file
> going forward. In other words: the config values you set in your
> `.env_{CONTEXT}` file will only take affect after the SECOND time
> the container boots.

## Install

Once configured, you can install the service permanently:

```
make install
```

Traefik will wait for the service healthcheck to complete, before
serving it. Check `make status` and wait for it to report as
`healthy` before proceeding.

## Setup client

Step-CA is strictly an API service, it has no user web interface. All
interaction with Step-CA is done with the command line client
[step-cli](https://smallstep.com/docs/step-cli/installation/), which
you should install on your workstation, using your package manager, or
according to those instructions.

> [!NOTE] 
> Some packages install only the binary named `step-cli`.
> `step-cli` is just another name for `step`. However, most of the
> Step-CA documentation uses the `step` name in place of `step-cli`.
> So if your package doesn't install `step` (Arch Linux is this way),
> you can add `alias step=step-cli` to your `~/.bashrc` or wherever
> you put that stuff on your workstation. You can also change the
> `STEP` variable at the top of the `Makefile` to use to point to any
> name/path.

Once you've installed the `step-cli` program, you need to configure it
to use your server:

```
make client-bootstrap
```

## Create and sign X.509 (TLS) certificates

Each time you want to create a new certificate, run:

```
make cert
```

This will prompt you to enter the subject name (CN), or fully
qualified domain name, of the host/entity you want to create the
certificate for. (eg. certificates may be created for a server, or for
a client, in the same way.)

You are required to enter the passphrase that you copied during the
initial installation process.

Once completed, it will create two new files on your worksation:

 * `certs/{DOMAIN}.crt` - This is the *public* certificate file for
   your host, along with the full public CA certificate chain.
 * `certs/{DOMAIN}.key` - This is the *private* key file (do not share)!

You can inspect the certificate file, and gather important details about it:

```
step-cli certificate inspect certs/{DOMAIN}.crt
```

The certificate has an expiration set in the future, according to the
default value set as
`STEP_CA_AUTHORITY_CLAIMS_DEFAULT_TLS_CERT_DURATION` in your
`.env_{CONTEXT}` file.

Install the certificate and key files into your target host
environment. The details of which are up to you, it is outside the
scope of this README.

> [!WARNING]
> The key file is **NOT** encrypted, keep it safe!

## Setup TLS clients

The certificates that Step-CA creates are untrusted by mainstream
trust stores, both as part of your operating system, and separately by
your web browser. Before clients can trust these certificates, you
will need to add the CA certificate chain to each of their
trust stores.

 * Here is the [trust
   management](https://wiki.archlinux.org/title/TLS#Trust_management)
   document on the Arch Linux wiki. It is also applicable to most
   other Linux distributions.
 * For other operating systems, you will need to consult their
   documentation for how you add root CA certificates.

To export the root CA certificate chain, run:

```
make inspect-ca-cert
```

You can also find the same thing publicly from your server at
`https://ca.example.com/roots.pem`.

If your client already has the `step-cli` tool installed and
configured for your CA, you can install the certs automatically:

```
# Install your public CA certificate into your user trust store:
step-cli certificate install $(step-cli path)/certs/root_ca.crt
```

And if you want remove it again later:

```
# Uninstall your public CA certificate from your user trust store:
step-cli certificate uninstall $(step-cli path)/certs/root_ca.crt
```

This will make simple command line programs, like `curl` work with
your certificates. However, web browsers have completly separate trust
stores, and these must be configured separately (also, it's not
recommended for most users to mess with their browsers security in
this way unless you really know what you're doing).

## Changing the root CA managerial passphrase

You must retain the manager passphrase in order to use the service. If
you lose it, I don't think there's a way to get it back. However, you
can change the password (assuming you still know the current one).

```
make change-password
```

> [!NOTE] 
> The change password script will ask you to enter two separate
> passwords.. Don't get confused, it's not asking for confirmation!
> The first question is asking for the OLD password (to decrypt), and the
> second questions is asking you for the NEW password (to encrypt). The
> passwords should be different! If you change your mind half-way
> through, press `Ctrl-C` to abort.

It's a good idea to immediately change the password, so that the
initial password is no longer sitting in the docker container logs.

## Security concerns

Obviously, having your root CA available publicly on the internet is a
lot less safe than running it in a secure private network. And even
that is less safe than running
[step-cli](https://smallstep.com/docs/step-cli/installation/) and
creating a new CA directly, on air-gapped laptop. Use the most locked
down environment that you can feel slightly inconvenienced to use.

You have a few ways to mitigate undesired access:

 * Run your Docker host machine inside of a secure private network,
   behind a firewall, or VPN.
 * Set `STEP_CA_IP_SOURCERANGE` in your `.env_{CONTEXT}` file, to
   limit the range of source IP addresses that are allowed access.
 * Turn off your server when not in use.
 
That last step is the most important one to consider. Install step-ca
on a completely separate Docker host (virtual) machine, separate from
what you use for anything else. You want to be able to *turn off* this
machine entirely, taking it offline, when you don't need it. If you
install other stuff on the same (virtual) machine, it defeats this
purpose. Of course, if you intend for this to be a full time service,
you may not afford this option, so you can do what you wish.
