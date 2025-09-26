# acme-dns

[acme-dns](https://github.com/joohoi/acme-dns?tab=readme-ov-file#acme-dns)
is a limited DNS server with RESTful HTTP API to handle ACME DNS
challenges easily and securely.

## Config

```
make config
```

Choose a dedicated sub-domain for acme-dns, e.g.,
`acme-dns.example.com`

Choose a dedicated sub-sub-domain for the DNS server itself, e.g.,
`auth.acme-dns.example.com`.

## Install

```
make install
```

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


## Traefik DNS resolvers

If you have a faulty DNS server that does not return canonical NS
records (e.g., `systemd-resolved`), you may need to set the root
resolvers used by Traefik:

```
make -C ../traefik reconfigure var=TRAEFIK_DNS_SERVERS_STATIC=true
make -C ../traefik reconfigure var=TRAEFIK_DNS_SERVER_1=1.1.1.1
make -C ../traefik reconfigure var=TRAEFIK_DNS_SERVER_2=1.0.0.1
make -C ../traefik reinstall
```
