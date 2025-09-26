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

## Stop other DNS resolvers on port 53

You may need to stop other DNS servers that are running on your Docker
host (but only if they are running on the default port, 53.)

To disable `systemd-resolved`, run this on the Docker host as `root`:

```
### Run this on the Docker host as root:
systemctl disable systemd-resolved
```

This will break DNS resolving on the host, so you must fix it by
hardcoding your preferred external DNS server into `/etc/resolv.conf`:

```
### Run this on the Docker host as root:
chattr -i /etc/resolv.conf 
rm -f /etc/resolv.conf

cat <<EOF > /etc/resolv.conf
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

chattr +i /etc/resolv.conf 
```

You should reboot your server after this change.

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
