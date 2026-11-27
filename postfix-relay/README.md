# postfix-relay

This is an outgoing forwarding-only Mail Transfer Agent (MTA) based on
[boky/postfix](https://github.com/bokysan/docker-postfix). By default,
only other containers on the same host who are allowed to connect to
the same Docker network can use this. Optionally, you can [publish the
submission port](#submission-port-and-tls) for the host or for other
machines. You must provide your own upstream outgoing SMTP server which
all mail will be forwarded to.

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
: mail.example.com:587

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

The relay's submission port is not published on the host by default. Set
`POSTFIX_RELAY_BIND_IP` to publish it: `127.0.0.1` accepts mail from this
host, and a LAN or WireGuard address accepts mail from other machines. The
host port is `POSTFIX_RELAY_SUBMISSION_PORT` (default `587`); instances that
publish on the same IP address each need their own port.

Clients must be allowed by `POSTFIX_RELAY_POSTFIX_mynetworks`, a comma
separated list of networks:

 * If it is blank, **all private networks** (`127.0.0.0/8`, `10.0.0.0/8`,
   `172.16.0.0/12`, `192.168.0.0/16`) are allowed. Set it whenever you
   publish the port on anything other than `127.0.0.1`.
 * Keep the subnet of the Docker network in the list, for containers and
   for processes on the Docker host. The network does not exist until the
   first `make install`; run `make config` again afterwards, and the subnet
   is added to whatever is already in the list.

If `POSTFIX_RELAY_BIND_IP` belongs to an interface that is not up when
Docker starts (e.g. WireGuard), the port cannot be bound and the container
may stay down. Order the Docker service after that interface, or run `make
start` once it is up.

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
`encrypt` to require TLS to the upstream, or to `secure` to also verify the
upstream's certificate and name (`encrypt` alone does not). If the upstream
uses implicit TLS instead of STARTTLS (normally port 465 rather than 587),
also set
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

