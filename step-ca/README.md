# Step-CA

[Step-CA](https://smallstep.com/docs/step-ca/) is a secure, online,
self-hosted Certificate Authority (CA). Its purpose is to issue (sign)
X.509 (TLS) certificates, and to securely store the private key for
the root CA.

## Config

```
make config
```

This creates and configures the `.env_{CONTEXT}_default` file from the
[.env-dist](.env-dist) template. Answer the questions that it poses,
to finish the config.

## Initialize the CA and retrieve the Step-CA admin password

You must initialize the CA before you install. This is important
because you need to make a record of the CA password, which is only
printed one time.

Initialize the CA, and take note of the password:

```
## This will work only before a fresh install:
make init-ca
```

 * Copy the username and password from the output.
 * Store the credentials someplace safe!

> [!NOTE]
> If this is *not* a fresh install, it won't print the
> password. If you don't know your password, you must start over,
> completely fresh. To do so, run `make destroy` before trying this
> again.

## Install

```
make install
```

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

Once bootstrapped, you can issue `step` commands directly from your
workstation, e.g.,:

```
step ca health
step ca roots
```

> [!NOTE] 
> `STEP_ROOT` must provide the .pem formatted proxy cert that Traefik
> fronts Step-CA with. This is most often a certificate from Let's
> Encrypt. `make proxy-cert` will download this to a temporary file.

## Manually create and sign X.509 (TLS) certificates

If you want to manually create a new certificate, run:

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
 * `certs/{DOMAIN}.p12` - This is the *private* key in an encrypted
   format (this is what the password it asked you was for). This is
   the preferred format for importing into a web browser.

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
creating a new CA directly, on an air-gapped laptop. Use the most
locked down environment that you can feel slightly inconvenienced to
use.

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

Unfortunately, the open-source Step-CA [does not
implement](https://smallstep.com/docs/step-ca/#limitations) External
Account Binding ([EAB -
RFC8555](https://www.rfc-editor.org/rfc/rfc8555#section-7.3.4)), which
would help tremendously in this regard.

## ACME

By default, Step-CA only configures the
[JWK](https://smallstep.com/docs/step-ca/provisioners/#jwk)
provisioner, which basically means it's limited to the manual
certificate requests like `make cert` does.

ACME is an API that offers a more automatic process of requesting,
issuing, and renewing TLS certificates. If you're familiar with Let's
Encrypt, you've already been using ACME. Step-CA offers the same
experience through this common API.

To turn on ACME, run:

```
make enable-acme
```

In your [Traefik](../traefik) instance, you will want to configure
ACME to point to your Step-CA instance. In the traefik directory, run
`make config`, and choose `Configure ACME`, choose `Step-CA` and you
will be prompted to enter the ACME endpoint URL, which is:

```
# This is the endpoint URL for Step-CA at ca.example.com ::
https://ca.example.com/acme/acme/directory
```

## Mutual TLS (mTLS)

### Enable mTLS in Trafeik config

Traefik needs to install the root CA certificate in order to trust
your client certificates.

In the Traefik `make config` menu, choose `Configure Certificate
Authorities (CA)`. You need to import your Step-CA root certificate
into your Traefik container's trust store. Choose one of the options
that does this, and it will prompt you for the endpoint and
fingerprint.

 * Endpoint: `https://ca.example.com`
 * Fingerprint: get this by running `make inspect-fingerprint` in the step-ca project.

Strong mTLS depends on both the client and server using certificates
from the same CA chain. However, you can relax that if you want. It
does not technically matter what ACME provider the server uses, it can
use Let's Encrypt, or Step-CA. The clients will be using Step-CA, but
they likely already have the Let's Encrypt CA trusted too (because of
the operating system and browser bundled CAs), so either will work. In
some cases that will be preferred, because clients won't need to add
modify their trust store, just add a single client certificate.

### Enable mTLS for an app

Most d.rymcg.tech apps have been made compatible with mTLS sentry
authentication. In each of their respective `make config` menus, there
is the option to turn on mTLS authentication:

```
? Do you want to enable sentry authentication in front of this app (effectively making the entire site private)?  
  No
  Yes, with HTTP Basic Authentication
  Yes, with Oauth2
> Yes, with Mutual TLS (mTLS)
```

Choosing this option enables mTLS for the given app. The next question
asks about what certificates it should allow in.

```
NGINX_MTLS_AUTHORIZED_CERTS: Enter comma separated list of allowed client certificate names (or blank to allow all) (eg. *.clients.www.example.com)
: *.clients.whoami.test.rymcg.tech,bob.geocities.com
```

In the example above, it would only let users in if the fit all of the following criteria:

 * The user must present a valid TLS certicate for all HTTP requests.
   (eg. with curl `--cacert`,`--cert`,`--key` options) and it must be
   signed by your own Step-CA instance.
 * The client certificate name (CN) value must match the list of
   `NGINX_MTLS_AUTHORIZED_CERTS` (wildcards allowed), comma separated.
 
So any of these clients are allowed access, assuming they are signed
by our Step-CA instance, and because they match the list of authorized
domains:

   * ✅ `bob.clients.whoami.test.rymcg.tech`
   * ✅ `alice.clients.whoami.test.rymcg.tech`
   * ✅ `ANYTHING.clients.whoami.test.rymcg.tech`
   * ✅ `bob.geocities.com`

None, of these clients are allowed access, not only because they
wouldn't be signed by our Step-CA instance, but also because they
don't match our list of authorized domains:
  
   * ❌ `thing2.rymcg.tech`
   * ❌ `ads.google.com`
   * ❌ `ANYTHING.else`

### In-app Authorization

The `{APP}_MTLS_AUTHORIZED_CERTS` variable does a crude form of
authorization for the app as a whole (it lets some certs in, while
rejecting others). For finer grained permissions than that, you need
to ask the app itself to do it, Traefik can't do it alone.

The `mtlsheader` middleware will forward the authenticated client
certificate name (CN) to the proxied service, via the header named
`X-Client-CN`. This is verified information that tells the backend app
the unique name of the client, based upon the signed name (CN) of the
certificate. Using this information, the application routes can do
fine grained authoriation (eg. sending http `200` or `403` codes on a
per page basis, based on user permissions stored in a database row per
name (CN)).

### Creating client certificates

You create client certificates the same way you create server
cerificates:

```
make cert
```

You will be asked to enter the name (CN) which must be a name that is
allowed by your Step-CA instance.

You can also generate client ceritificates via ACME, if you want to
setup a client that way. Give
[acme.sh](https://github.com/acmesh-official/acme.sh) a try.

### Naming client certificates (CN)

Although client certificate names do have to look like internet domain
names, but unless you're issuing client certificates via ACME, they do
not need to have DNS. You are free to make up whatever domain names
you want for your user certificates. However, here is a good naming
convention you may want to use, as a subdomain of the app you are
creating the certificates for:

```
NAME.clients.app.example.com
```

If you create your client certificates like that, they will retain a
relation back to where they are supposed to go. However, if a user
needs access to multiple apps, they will need to manage certificates.

A better way might be to create a central store where users have
unique IDs inside of your organization:

```
NAME.users.example.com
```

## Testing TLS with curl

Assuming you have already deployed [whoami](../whoami) and configured
it for mTLS, and you have the following config:

```
ROOT_STEP_CA_CERT=~/.step/certs/root_ca.crt
CLIENT_CERT=~/git/vendor/enigmacurry/d.rymcg.tech/step-ca/certs/tony.clients.whoami.example.com.crt
CLIENT_KEY=~/git/vendor/enigmacurry/d.rymcg.tech/step-ca/certs/tony.clients.whoami.example.com.key

WHOAMI_URL=https://whoami.example.com
```

### Test the root CA

If your system has no trust of the Step-CA root certificate, curl will
show you this error, which is normal of any "self-signed" certificate:

```
$ curl ${WHOAMI_URL}
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```

It means that curl is politely refusing to show you the content
because the certificate is not trusted. However, you can bypass the
check with the `--insecure` (or `-k`) flag:

```
## UNSAFE: This will bypass TLS validation entirely, allowing any certificate.
curl --insecure ${WHOAMI_URL}
```

To fix this, you can add the root CA to your system trust store:

```
## Only do this if you're really sure you've secured your passwords!
step-cli certificate install ${ROOT_STEP_CA_CERT}
```

### Test mTLS

If your server requires mTLS, but you haven't provided your client
certificate and key, you'll get this error:

```
```
