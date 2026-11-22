# acme-dns

[acme-dns](https://github.com/joohoi/acme-dns?tab=readme-ov-file#acme-dns)
is a DNS server limited in scope to handling ACME DNS challenges
easily and securely.

## Config

```
make config
```

Choose a dedicated sub-domain for acme-dns, e.g.,
`acme-dns.example.com`

## Open ports in your firewall

You need to open the following ports in your firewall:

 * `53` both UDP and TCP (DNS).
 * `2890` TCP (API; configurable via `ACME_DNS_API_PORT`).

## Setup DNS

On your chosen domain's primary DNS server, create two records:

 * an `A` record for your acme-dns sub-domain pointing to your
   server's public IP address:
 
```
acme-dns.example.com.  A  123.123.123.123.
```

 * an `NS` record for your acme-dns sub-domain pointing to the name
   above:

```
acme-dns.example.com.  NS  acme-dns.example.com.
```

## Install

```
make install
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
