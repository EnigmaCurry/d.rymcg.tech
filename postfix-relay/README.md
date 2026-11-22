# postfix-relay

This is an outgoing forwarding-only Mail Transfer Agent (MTA) based on
[boky/postfix](https://github.com/bokysan/docker-postfix). Only other
containers on the same host who are allowed to connect to the same
Docker network can use this. You must provide your own upstream
outgoing SMTP server which all mail will be forwarded to.

## Config

```
make config
```

Enter the domain name for this postfix instance:

```
POSTFIX_RELAY_TRAEFIK_HOST: Enter the domain name for this instance
: smtp.d.example.com
```

Enter the upstream SMTP server connection details:

```
POSTFIX_RELAY_RELAYHOST: Enter the outgoing SMTP server domain:port (eg. smtp.example.com:587)
: mail.example.com:465

POSTFIX_RELAY_RELAYHOST_USERNAME: Enter the outgoing SMTP server username
: username@example.com

POSTFIX_RELAY_RELAYHOST_PASSWORD: Enter the outgoing SMTP server password
: xxxxxxxxxxxxxxxxxxxx
```

Select which network subdomains should be masked at the root domain
(this is optional, and can be used to hide private subdomains from the
email headers):

```
POSTFIX_RELAY_MASQUERADED_DOMAINS: Enter the root domains (separated by space) that should mask its sub-domains
: example.com example.org
```

## Submission port and TLS

The relay's submission port (587) is published on the host at
`POSTFIX_RELAY_BIND_IP` (default `127.0.0.1`, so only this host can submit
mail). Set it to a LAN or WireGuard address to accept mail from other
machines; those clients must also be allowed by
`POSTFIX_RELAY_POSTFIX_mynetworks`.

There are two independent TLS hops, each configurable:

**Clients to this relay** (`POSTFIX_RELAY_POSTFIX_smtpd_tls_security_level`,
default `may`). The image only ships a self-signed certificate, so clients
that verify certificates will reject it, and some of them (e.g. plMail)
negotiate STARTTLS whenever it is offered. On a trusted, already-encrypted
network (e.g. a WireGuard subnet) where senders are authenticated by IP via
`mynetworks` and no credentials cross the wire, set it to `none` to make
those clients work. To keep STARTTLS, leave it at `may` and provide a
trusted certificate.

**This relay to the upstream server**
(`POSTFIX_RELAY_POSTFIX_smtp_tls_security_level`, default `may`). Set it to
`encrypt` to require TLS to the upstream. If the upstream uses implicit TLS
instead of STARTTLS (normally port 465 rather than 587), also set
`POSTFIX_RELAY_POSTFIX_smtp_tls_wrappermode=yes`:

```
POSTFIX_RELAY_RELAYHOST=smtp.example.com:465
POSTFIX_RELAY_POSTFIX_smtp_tls_security_level=encrypt
POSTFIX_RELAY_POSTFIX_smtp_tls_wrappermode=yes
```

After changing any of these, run `make install`.

## Install

```
make install
```

