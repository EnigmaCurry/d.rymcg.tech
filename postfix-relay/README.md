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

Select which other Docker networks should be allowed to send mail:

```
? Select the Docker networks allowed to send mail
> [x] backup-volume_default
  [ ] filestash_test_default
  [x] forgejo_forgejo
  [ ] homepage_default
  [ ] immich_default
  [ ] invidious_default
v [ ] jupyterlab_default
```

Select which network subdomains should be masked at the root domain
(this is optional, and can be used to hide private subdomains from the
email headers):

```
POSTFIX_RELAY_MASQUERADED_DOMAINS: Enter the root domains (separated by space) that should mask its sub-domains
: example.com example.org
```

## Install

```
make install
```

