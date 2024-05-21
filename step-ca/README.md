# Step-CA

[step-ca](https://smallstep.com/docs/step-ca/) is a secure, online,
self-hosted Certificate Authority (CA), for issuing (signing) X.509
(TLS) and/or SSH certificates.

## Config

```
make config
```

## Install

You must run step-ca the first time interactively. This is important
because you need to make a record of the CA password, which is only
printed one time in the log:

```
# Run the step-ca interactively the first time only:
make up service=step-ca
```

In the log output, you should find your new password, which is only
printed this one time:

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
> Starting the container up one time, and then shutting it
> down, also served another purpose: on the first run, the Step-CA
> service automatically creates `/home/step/config/ca.json` (in the
> container volume), this is important to know the order in which it
> creates it, because our `config` container requires this file to
> already exist (it wants to modify an existing config file), and
> since its supposed to run *before* the step-ca container. So, by
> running the service one time, and shutting it down, it ensures that
> file now exists in the config volume.

Now you can install the service permanently:

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

> [!NOTE] Some packages install only the binary named `step-cli`.
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

Each time you want to create a certificate, run:

```
make client-cert
```

This will prompt you to enter the fully qualified domain name of the
host you want to create the certificate for.

You are required to enter the passphrase that you copied during the
initial installation process.

Once completed, it will create two new files on your worksation:

 * `certs/{DOMAIN}.crt` - This is the *public* certificate file for your host.
 * `certs/{DOMAIN}.key` - This the *private* key file (do not share)!

You can inspect the certificate file, and gather important details about it:

```
step-cli certificate inspect certs/{DOMAIN}.crt
```
