# Tour of d.rymcg.tech

This guide will show you how to self-host web applications on your
 Docker server with
 [d.rymcg.tech](https://github.com/enigmacurry/d.rymcg.tech).

This guide is abbreviated and only shows a subset of the available
services provided by d.rymcg.tech. Please consult the main
[README.md](README.md#services) for a full list, and follow the links
to the documentation of each service that you intend to install.

## Requirements

This guide assumes that you have already performed the following
steps:

  * Create your workstation (choose one):
 
    * [WORKSTATION_LINUX.md](WORKSTATION_LINUX.md) - Setup your workstation on Linux.
    * [WORKSTATION_WSL.md](WORKSTATION_WSL.md) - Setup your workstation on Windows (WSL).

  * Create your Docker server:
  
    * [DOCKER.md](DOCKER.md) - Create your Docker server on bare
      metal, VM, or cloud server.

All of the commands written in this guide are to be run on your
workstation:

  * Switch your workstation's Docker context to the server you wish to
    control:
    
```
d context
```

## Acme-DNS
 
```
d make acme-dns config
```

Choose a dedicated sub-domain for acme-dns, e.g.,
`acme-dns.example.com`, along with the IP address and port information
it asks for.

On your main DNS server:

 * Create a type `A` record point `acme-dns.example.com` to the IP address of
   your server.
 * Create a type `NS` record pointing `acme-dns.example.com` to itself
   `acme-dns.example.com`,

Open the following ports in your server's firewall:

 * `53` both UDP and TCP (DNS).
 * `2890` TCP (API; configurable via `ACME_DNS_API_PORT`).

Install acme-dns:

```
d make acme-dns install
```

Wait for the service to start:

```
Waiting until all services are started and become healthy ...
Still waiting for services to finish starting: acme-dns-acmedns-1
Still waiting for services to finish starting: acme-dns-acmedns-1
All services healthy.
```

If it is taking an exceedingly long time, press Ctrl-C and investigate:

```
d make acme-dns logs
```

Make sure the service is listed as `healthy` before proceeding:

```
d make acme-dns status

d make acme-dns wait
```

## Traefik

```bash
d make traefik config
```

This will create the Traefik config file in
`~/git/vendor/enigmacurry/d.rymcg.tech/traefik/.env_{CONTEXT}_default`
and an interactive menu to change its settings:

```
? Traefik:
> Config
  Install (make install)
  Admin
  Exit (ESC)
```

### Config

```
? Traefik Configuration:
> Traefik user
  Entrypoints (including dashboard)
  TLS certificates and authorities
  Middleware (including sentry auth)
  Advanced Routing (Layer 7 / Layer 4 / Wireguard)
  Error page template
v Logging level
```

#### Traefik user

  * Create the traefik user.

#### TLS certificates and authorities

  * Configure TLS certificates

  * Create a new certificate

Create a new wildcard certificate for your domain:

```text
Enter the main domain (CN) for this certificate (eg. `d.rymcg.tech` or `*.d.rymcg.tech`)
: widgets.example.com
Now enter additional domains (SANS), one per line:
Enter a secondary domain (enter blank to skip)
: *.widgets.example.com
Enter a secondary domain (enter blank to skip)
:

Main domain:
 widgets.example.com
Secondary (SANS) domains:
 *.widgets.example.com
```

This example chose the base domain `widgets.example.com` and
`*.widgets.example.com` so that has an entire sub-domain that is
dedicated to this docker context. If you want to dedicate the entire
domain, you could use `example.com` and `*.example.com` instead.

Choose `Done`.

 * Configure ACME (Let's Encrypt or Step-CA)

 * Choose `Acme.sh + acme-dns`

 * Choose `Let's Encrypt (production)`

```text
> Which ACME provider do you want to use? Acme.sh + ACME-DNS (new; recommended!)
Set TRAEFIK_ACME_ENABLED=false
Set TRAEFIK_STEP_CA_ENABLED=false
Set TRAEFIK_ACME_SH_ENABLED=true
Set TRAEFIK_ACME_CHALLENGE=dns

> Which ACME server should acme.sh use? Let's Encrypt (production)
Set TRAEFIK_ACME_SH_ACME_CA=acme-v02.api.letsencrypt.org
Set TRAEFIK_ACME_SH_ACME_DIRECTORY=/directory
Set TRAEFIK_ACME_SH_TRUST_SYSTEM_STORE=true

TRAEFIK_ACME_SH_ACME_DNS_BASE_URL: ACME-DNS base URL (e.g. https://acme-dns.example.com:2890) (eg. https://auth.acme-dns.io)
: https://acme-dns.example.com:2890

TRAEFIK_ACME_SH_DNS_RESOLVER: Trusted DNS resolver IP used inside acme-sh container (eg. 1.1.1.1)
: 1.1.1.1
```

#### Create DNS records (CNAME and A)

Look for the CNAME records output to the screen, e.g.:

```text
### EXAMPLE:
Create these CNAME records (on your root domain's DNS server) BEFORE traefik install:

    _acme-challenge.widgets.example.com.   CNAME   615b56da-6105-4b80-baee-7612decd3b06.auth.acme-dns.io.
```

You must create the `CNAME` record on your root domain's DNS server.

You must also create a wildcard `A` record for your clients to access
the services, pointing to your server's public IP address. e.g.:

```text
### EXAMPLE:
    *.widgets.example.com.   A   123.123.123.123
```

### Install Traefik

Go back to the main menu and choose `Install (make install)`.

#### Check acme-sh logs for issuance of the certificate

```bash
d make traefik logs service=acme-sh
```

Look in the log for the certificate to be successfully issued:

```text
acme-sh-1  | 2025-09-12T18:16:01.965738376Z
acme-sh-1  | 2025-09-12T18:16:01.970307171Z [entrypoint:acme-sh] Public ACME CA detected (acme-v02.api.letsencrypt.org); skipping TOFU and using system trust.
...
acme-sh-1  | 2025-09-12T18:16:02.292281439Z [entrypoint:acme-sh] ACME server: https://acme-v02.api.letsencrypt.org/directory
...
acme-sh-1  | 2025-09-12T18:16:02.991015073Z [entrypoint:acme-sh] Requesting certificate:
acme-sh-1  | 2025-09-12T18:16:02.991023715Z [entrypoint:acme-sh]   CN:   widgets.example.com
acme-sh-1  | 2025-09-12T18:16:02.991026764Z [entrypoint:acme-sh]   SANs: *.widgets.example.com
acme-sh-1  | 2025-09-12T18:16:04.468239771Z [Fri Sep 12 18:16:04 UTC 2025] Using CA: https://acme-v02.api.letsencrypt.org/directory
acme-sh-1  | 2025-09-12T18:16:04.585778816Z [Fri Sep 12 18:16:04 UTC 2025] Account key creation OK.
acme-sh-1  | 2025-09-12T18:16:04.747781785Z [Fri Sep 12 18:16:04 UTC 2025] Registering account: https://acme-v02.api.letsencrypt.org/directory
acme-sh-1  | 2025-09-12T18:16:05.311626804Z [Fri Sep 12 18:16:05 UTC 2025] Registered
.........
acme-sh-1  | 2025-09-12T18:17:41.315548009Z [Fri Sep 12 18:17:41 UTC 2025] Cert success.
acme-sh-1  | 2025-09-12T18:17:41.318576644Z -----BEGIN CERTIFICATE-----
.........
acme-sh-1  | 2025-09-12T18:17:41.318890370Z -----END CERTIFICATE-----

acme-sh-1  | 2025-09-12T18:17:41.677056823Z [entrypoint:acme-sh] Certificate details for widgets.example.com:
acme-sh-1  | 2025-09-12T18:17:41.727222044Z   notBefore=Sep 12 17:19:10 2025 GMT
acme-sh-1  | 2025-09-12T18:17:41.735464637Z   notAfter=Dec 11 17:19:09 2025 GMT
acme-sh-1  | 2025-09-12T18:17:41.735523096Z   issuer=C=US, O=Let's Encrypt, CN=E8
acme-sh-1  | 2025-09-12T18:17:41.735529514Z   subject=CN=widgets.example.com
acme-sh-1  | 2025-09-12T18:17:41.735534692Z   X509v3 Subject Alternative Name:
acme-sh-1  | 2025-09-12T18:17:41.735540318Z       DNS:*.widgets.example.com, DNS:widgets.example.com
acme-sh-1  | 2025-09-12T18:17:41.736623193Z [entrypoint:acme-sh] Installed files under: /certs/widgets.example.com
acme-sh-1  | 2025-09-12T18:17:41.739492248Z + exec crond -n -s -m off
```

## Whoami

Install whoami as a test to use the certificate:

```bash
$ d make whoami config

Configuring environment file: .env_widgets_default
WHOAMI_TRAEFIK_HOST: Enter the whoami domain name (eg. whoami.example.com)
: whoami.widgets.example.com

> Do you want to enable sentry authorization in front of this app (effectively making the entire site private)? No

$ d make whoami install
```

### Check the TLS cert is correctly used

```bash
d script tls_debug whoami.widgets.example.com
```

This will connect to your whoami service and print information about
the TLS certificate. The important bit to watch for is this:

```text
---
Certificate chain
 0 s:CN=widgets.example.com
   i:C=US, O=Let's Encrypt, CN=E8
   a:PKEY: id-ecPublicKey, 256 (bit); sigalg: ecdsa-with-SHA384
   v:NotBefore: Sep 12 17:19:10 2025 GMT; NotAfter: Dec 11 17:19:09 2025 GMT
 1 s:C=US, O=Let's Encrypt, CN=E8
   i:C=US, O=Internet Security Research Group, CN=ISRG Root X1
   a:PKEY: id-ecPublicKey, 384 (bit); sigalg: RSA-SHA256
   v:NotBefore: Mar 13 00:00:00 2024 GMT; NotAfter: Mar 12 23:59:59 2027 GMT
---
```

This shows that Let's Encrypt issued the certificate and the validity period.


## Forgejo

```
d make forgejo config
```

```
d make forgejo install
```

```
d make forgejo open
```

This will open a configuration page. DO NOT fill any config at this
time. Scroll all the way to the bottom and open the `Administrator
account settings`. Enter ONLY the following information:

 * Your administrator username, e.g. `root`. (this should be separate
   from your primary user account.)
 * Email address, e.g. `root@example.com`.
 * Password.
 * Confirm password.
 
Finally, click the `Install Forgejo` button. Once logged in as the
root user, you can create additional accounts via the `Site
administration` menu.

To enable SSH access to git repositories, you must enable the Traefik
SSH entrypoint:

```
d make traefik config
```

```
? Traefik:
> Config
  Install (make install)
  Admin
  Exit (ESC)

? Traefik Configuration:
  Traefik user
> Entrypoints (including dashboard)
  TLS certificates and authorities
  Middleware (including sentry auth)
  Advanced Routing (Layer 7 / Layer 4 / Wireguard)
  Error page template
v Logging level

? Traefik entrypoint config
  Show enabled entrypoints
> Configure stock entrypoints
  Configure custom entrypoints

? Select entrypoint to configure:
^ websecure : HTTPS (TLS encrypted HTTP)
  web_plain : HTTP (unencrypted; specifically NOT redirected to websecure; must use different port than web)
  mqtt : MQTT (mosquitto) pub-sub service
> ssh : SSH (forgejo) git (ssh) entrypoint
  xmpp_c2s : XMPP (ejabberd) client-to-server entrypoint
  xmpp_s2s : XMPP (ejabberd) server-to-server entrypoint
v mpd : Music Player Daemon (mopidy) control entrypoint

> Do you want to enable the ssh entrypoint? Yes

TRAEFIK_SSH_ENTRYPOINT_HOST: Enter the host ip address to listen on (0.0.0.0 to listen on all interfaces) (eg. 0.0.0.0)

: 0.0.0.0

TRAEFIK_SSH_ENTRYPOINT_PORT: Enter the host port to listen on (eg. 2222)

: 2222

? Is this entrypoint downstream from another trusted proxy?
> No, clients dial directly to this server. (Turn off Proxy Protocol)
  Yes, clients are proxied through a trusted server. (Turn on Proxy Protocol)
```

Press ESC three times to get back to the main menu, and then select
install:

```
? Traefik:
  Config
> Install (make install)
  Admin
  Exit (ESC)
```

Watch for any errors, and finally, choose `Exit`.

## Traefik-Forward-Auth

```
d make traefik-forward-auth config
```

```
TRAEFIK_FORWARD_AUTH_HOST: Enter the traefik-foward-auth host domain name (eg. auth.example.com)

: auth.widgets.example.com

TRAEFIK_FORWARD_AUTH_COOKIE_DOMAIN: Enter the cookie domain name (ie ROOT domain) (eg. example.com)

: widgets.example.com

? Select the OAuth provider to use
> forgejo
  github
  google
  discord

TRAEFIK_FORWARD_AUTH_FORGEJO_DOMAIN: Enter your forgejo domain name (eg. git.example.com)

: git.widgets.example.com

```

At this point it will open your browser to the forgejo instance,
possibly asking you to sign in, and then you need to create a new
OAuth2 application:

 * Application name: `widgets.example.com`
 * Redirect URIs: `https://auth.widgets.example.com/_oauth`
 * Select `Confidential client`.
 * Click `Create application`.

This will show you two things:

 * Client ID
 * Client secret
 
Copy both of these and fill in the values back in your terminal:

```
TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_ID: Copy and Paste the OAuth2 client ID here

: 38d6c7f7-c712-43a9-967c-27888819e85f

TRAEFIK_FORWARD_AUTH_PROVIDERS_GENERIC_OAUTH_CLIENT_SECRET: Copy and Paste the OAuth2 client secret here

: gto_4g54tazy7oyslypqhr7z7khundcmtwezlkdeyghe7ctj7k4gltvq

TRAEFIK_FORWARD_AUTH_LOGOUT_REDIRECT: Enter the logout redirect URL

: https://git.widgets.example.com/logout
```

Now install traefik-forward-auth:

```
d make traefik-forward-auth install
```

With OAuth2 sentry authorization enabled, users are authorized to
access apps only if they are a member of an authorized group for that
app. You need to create the group membership lists in the Traefik
config:

```
d make traefik config
```

Create an authorization group named `admin`, adding your forgejo
username to it (email address):

```
? Traefik:
> Config
  Install (make install)
  Admin
  Exit (ESC)

? Traefik Configuration:
  Traefik user
  Entrypoints (including dashboard)
  TLS certificates and authorities
> Middleware (including sentry auth)
  Advanced Routing (Layer 7 / Layer 4 / Wireguard)
  Error page template
v Logging level

? Traefik middleware config:
  MaxMind geoIP locator
> OAuth2 sentry authorization (make sentry)

? Sentry Authorization Manager (main menu):
> Group Manager
  User Manager
  List all members
  List authorized callback URLs
  Quit

> Sentry Authorization Manager (main menu): Group Manager
? Choose a group to manage
> Create a new group

? Enter the name of the group to create: admin

> Do you want to add users to this group now? Yes

Enter the new user id(s) to add, one per line:
? Enter a user ID (Press Esc or enter a blank value to finish)  me@example.com
```

Replace `me@example.com` with the same email address that you used to
sign up for your personal account in Forgejo. You can add more users
to the group if you wish. When done, enter a blank line.

Now reconfigure the whoami app to require authentication:

```
d make whoami config
```

```
WHOAMI_TRAEFIK_HOST: Enter the whoami domain name (eg. whoami.example.com)

: whoami.pi.example.com

? Do you want to enable sentry authorization in front of this app (effectively making the entire site private)?
  No
  Yes, with HTTP Basic Authentication
> Yes, with Oauth2
  Yes, with Mutual TLS (mTLS)

? Which authorization group do you want to permit access to this app?
> admin
```

And reinstall whoami:

```
d make whoami install
```

Open whoami, and notice that it now requires authentication through
forgejo before it will show you the whoami page:

```
d make whoami open
```

## Postfix Relay

```
d make postfix-relay config
```

```
POSTFIX_RELAY_TRAEFIK_HOST: Enter the domain name for this instance

: smtp.d.example.com
```


```
POSTFIX_RELAY_RELAYHOST: Enter the outgoing SMTP server domain:port (eg. smtp.example.com:587)

: mail.example.com:465

POSTFIX_RELAY_RELAYHOST_USERNAME: Enter the outgoing SMTP server username

: username@example.com

POSTFIX_RELAY_RELAYHOST_PASSWORD: Enter the outgoing SMTP server password

: xxxxxxxxxxxxxxxxxxxx
```

```
POSTFIX_RELAY_MASQUERADED_DOMAINS: Enter the root domains (separated by space) that should mask its sub-domains

: example.com example.org
```

Install postfix-relay:

```
d make postfix-relay install
```

Test sending email:

```
(
RECIPIENT="recipient@example.com"
SENDER="root@localhost"
SUBJECT="Test Email"
BODY="This is a test email sent from Docker."

docker run --rm \
  --network postfix-relay_default \
  -e RECIPIENT="$RECIPIENT" \
  -e SENDER="$SENDER" \
  -e SUBJECT="$SUBJECT" \
  -e BODY="$BODY" \
  alpine sh -c 'apk add --no-cache msmtp && \
  echo -e "Subject: $SUBJECT\n\n$BODY" | \
  msmtp --from="$SENDER" \
        --host=postfix-relay-postfix-relay-1 \
        --port=587 \
        --tls=off \
        --tls-starttls=off \
        "$RECIPIENT" && \
        echo "Email sent" || \
        echo "Email failed to send"'
)
```

## Step-CA

## Docker Registry

## SFTP (and Thttpd)

## MinIO S3 (and Filestash)

## Homepage

## Nginx and PHP

## Jupyterlab
