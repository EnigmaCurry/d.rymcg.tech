# mailu

[mailu](https://mailu.io/) is an email service suite, including SMTP, IMAP, and
webmail clients.

This configuration is focused on a private, personal email platform, that
relays all incoming and outgoing email through an external IMAP and SMTP service
provider. All connections *into* the system must come through a private VPN
([wireguard](../wireguard)).

If you are instead looking for a *public* email server, [check out the official
mailu docs instead](https://mailu.io/1.9/setup.html). But if you try that, get
ready for the uphill battle of evading IP blocklists and constantly checking if
your emails are actually getting recieved and not going directly to spam. 

Its much easier and more reliable to use an established external SMTP server as
a relay, and let someone else deal with the problem of delivering your mail. And
since you need someone to send your mail, you might as well let them receive
your mail too. IF you were to clumsily delete your mailu instance, or forget to
pay your VPS host, you'll know that your mails are still being collected and
will be ready to download again once you re-install/re-configure mailu.

Since you (and your mail clients) will be the only ones who connects to the mail
server, it does not need to be public at all. By wrapping the service in
wireguard, you eliminate whole classes of security concerns (however this code
has not been independently audited, so please open an issue if you find anything
wrong/weird).

## Prerequisites

 * You will need an existing email account, on an external email service, that
   provides IMAP and SMTP access, and is already receiving your mail. This
   account could be an individual user email address, or a catch-all account
   that forwards mail for an entire domain.
 * You need to install [traefik](../traefik) and [wireguard](../wireguard).
 * You will need a domain name for your mail server, with a DNS `A` record (eg.
   `mail.example.com`) pointed to your Traefik server's IP address. The `MX`
   records should be pointing to your upstream mail provider. Do not add any
   `MX` records for your private mailu instance.
 
## Network diagram

* Your mail client/browser connects to the [wireguard](../wireguard) network on
  port 51820.
* The wireguard DNS returns the private ip address for `mail.example.com`.
* Client connects to `mail.example.com` goes through the Traefik `vpn`, `smtp`,
  or `imap` endpoint depending on the protocol.
* Traefik sits on both the `traefik-wireguard` and `traefik-mail` networks and
  routes connections to the mailu frontend.
* Examples subnets:
  * Wireguard clients: `10.15.0.0/24`
  * `traefik-wireguard`: `172.15.0.0/16`
  * `traefik-mail`: `172.16.0.0/24`

```
         Wireguard client ------------------> Traefik ---------------> Mailu Frontend
             
wireguard network ----> traefik-wireguard network --> traefik-mail network --->

client:10.15.0.2                     traefik:172.15.0.3/172.16.0.3     mailu:172.16.0.13
```

## Config

Run `make config` and answer the questions to create the `.env` file:

 * `MAILU_TRAEFIK_HOST` the mailu server hostname, eg `mail.example.com`
 * `SUBNET` the subnet for the `mail` docker network, eg `192.168.203.0/24`
 * `DOMAIN` the main mail domain, ie. the part that comes after the `@` in your
   main email address, eg. `example.com`.
 * `RELAYHOST` The upstream SMTP (TLS) server hostname and port, in special
   syntax with square brackets around the name: `[smtp.example.net]:465`
 * `RELAYUSER` The upstream SMTP username, eg. `user@example.com`.
 * `RELAYPASSWORD` The upstream SMTP password.

Setup the DNS for the wireguard clients. Simply edit the `/etc/hosts` file of
the Docker host operating system:

```
## /etc/hosts
## This is the default Traefik IP address on the traefik-wireguard network.
## This will allow VPN clients to resolve the mail server (through traefik):
172.15.0.3      mail.example.com
```

## Install

Start the mail services with `make install`.

Follow the [wireguard](../wireguard) instructions for connecting your VPN
client.

## Create admin account

Create your main email account (this will be an administrator):

```
make admin
```

When asked, enter the username you would like, and the initial password will be
displayed.

Open the browser and sign into the admin interface:

```
make open
```

## Add external IMAP account

SMTP is already setup for your external account, allowing you to send email to
external domains. You still need to setup IMAP in order to receive email:

 * Click on `Fetched Accounts`
 * Click `Add an account`
 * Add the hostname, tcp port (eg. 993 for TLS encrypted IMAP)
 * Click `Enable TLS`
 * Enter the *external** IMAP username and password
 * Choose whether to leave emails on the upstream server, or not.
 
**NOTE**: The fetchmail client has been [modified to allow Push emails (IMAP
IDLE)](https://github.com/EnigmaCurry/Mailu/commit/ea4e883d88a5dc00a60dd8c845f2b327fab42b5d).
This means that emails will appear in your inbox practically immediately as they
are sent (you do not need to wait for a polling interval like the original mailu
client did). However, this means that you cannot have more than one `Fetched
account`, as the `fetchmail` client will block on the IDLE command, and cannot
process more than one account.

## Add all the main domains

If you would like to send mail from email addresses that are not for the main
domain you added, you can add additional domains:

 * Click on `Mail domains`, and find the *main* domain that should already
   exist. Click the `*` icon and find the `Alternative domain list` page.
 * Click `Add alternative`, and add as many additional domain names as you want.
 
## TLS certificates

The TLS certificate for the web browser (admin and webmail clients) uses the
Lets Encrypt ACME provider, and will therefore be a valid trusted certificate.

The TLS certificates for the SMTP and IMAP servers are self-signed certiticates
from [certificate-ca](../_terminal/certificate-ca). Traefik is proxying the TCP
connection with TLS passthrough directly to the mailu frontend. 

The self-signed certificate is valid for 100 years. Most mail clients allow you
to "pin" a self-signed TLS certificate, and will therefore no longer nag you
about the fact that it is self-signed. You will want to verify the fingerprint
when it first connects, to ensure the validity:

```
## Verify the TLS certificate fingerprints match what your mail clients say:
make fingerprint
```
