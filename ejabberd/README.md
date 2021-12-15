# ejabberd

[ejabberd](https://github.com/processone/ejabberd) is an XMPP server written in
erlang.

Since Traefik does not understand the XMPP protocol, TLS must be handled by the
service container (ejabberd) directly. In this configuration, Traefik forwards
raw TCP port 5222 to the container, and ejabberd handles TLS itself via
STARTTLS. (STARTTLS is the preferred automatic protocol that Gajim supports,
instead of direct TLS. This allows logging by entering just a Jabber ID [JID]
and a password, and without needing to click into the Advanced Settings of
Gajim.)

This ejabberd configuration *will not* share the main TLS certificate used by
Traefik. You need to provide your own certificate, placed into a volume (eg.
with certbot), or you may generate a local certificate authority and self-signed
certificate as this example will show.

To generate a new a self-signed certificate, use the included
[cert-manager.sh](../certificate-ca) script to create a Certificate Authority
and a certificate/key pair for ejabberd's use:

```
EJABBERD_HOST=xmpp.example.com
../certificate-ca/cert-manager.sh build
../certificate-ca/cert-manager.sh create_ca
../certificate-ca/cert-manager.sh create ${EJABBERD_HOST} 9000 9000
```

`cert-manager.sh` will have created a new CA key stored in the
`local-certificate-ca` volume, and a certificate for ejabberd in the
`local-certificate-ca_xmpp.example.com` volume. The permissions will be set for
UID 9000 and GID 9000, the same as the ejabberd user account in the container.

The first time you connect, the Gajim XMPP client will offer to pin the
self-signed certificate. Alternatively, you may install the Certificate
Authority used to sign the certificate, into your (preferably containerized)
local trust store. (See [certificate-ca](../certificate-ca) for details and
caveats.)

Traefik is configured to support IP address filtering, in order to limit which
client and server addresses may connect to the XMPP services. See
`C2S_SOURCERANGE` and `S2S_SOURCERANGE` which are the client-to-server and
server-to-server XMPP protocol IP address ranges allowed, written in CIDR
format.

### ejabberd helper tool

`helper.sh` is included to encapsulate some of the maintaince tasks of ejabberd.

Create a new XMPP user with a random password:

```
./helper.sh register ryan@xmpp.example.com
```

Create a conference room (MUC):

```
./helper.sh create_room test xmpp.example.com
```

### Test login

Create a user with the helper.sh script as shown above. Copy the password it
prints out. Use Gajim to login with the JID and password. If using a self-signed
certificate, it will ask to pin the certificate the first time connecting
(confirm the certificate details upon connect by clicking the checkbox `Add this
certificate to the list of trusted certificates`, it may ask twice..)


