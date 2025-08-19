# acme-dns

[acme-dns](https://github.com/joohoi/acme-dns?tab=readme-ov-file#acme-dns)
is a limited DNS server with RESTful HTTP API to handle ACME DNS
challenges easily and securely.

## config

```
make config
```

Choose a dedicated sub-domain for acme-dns, e.g.,
`acme-dns.example.com`

Choose a dedicated sub-sub-domain for the DNS server itself, e.g.,
`auth.acme-dns.example.com`.

## install

```
make install wait
```

## Setup DNS

On your chosen domain's primary DNS server, create a CNAME record
pointing to your acme-dns server.

For example:

```
_acme-challenge.mrfusion.rymcg.tech.  CNAME  d420c923-bbd7-4056-ab64-c3ca54c9b3cf.acme-dns.rymcg.tech.
```

## Disable registration

After all of your ACME clients have registered for the first time, you
may want to disable registration to limit any further registrations by
setting `ACME_DNS_DISABLE_REGISTRATION=true`. There is a command
shortcut that will edit this setting and restart the service:

```
## DISABLE registration and restart the server:
make registration-disable
```

To re-enable registration at a later time:

```
## ENABLE registration and restart the server:
make registration-enable
```
