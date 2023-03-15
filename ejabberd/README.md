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

Note: this configuration only works on **amd64**

### Enable Traefik XMPP Endpoints

You must enable the `xmpp_c2s` and `xmpp_s2s` Traefik endpoints and
restart Traefik:

```
make -C ~/git/vendor/enigmacurry/d.rymcg.tech/traefik \
    reconfigure var=TRAEFIK_XMPP_C2S_ENTRYPOINT_ENABLED=true
make -C ~/git/vendor/enigmacurry/d.rymcg.tech/traefik \
    reconfigure var=TRAEFIK_XMPP_S2S_ENTRYPOINT_ENABLED=true
make -C ~/git/vendor/enigmacurry/d.rymcg.tech/traefik \
    install
```

### Configure ejabberd

```
make config
```

This ejabberd configuration *will not* share the main TLS certificate
used by Traefik. Instead, a self-signed 100 year certificate is used
via [cert-manager.sh](../_terminal/certificate-ca), and is
automatically installed during configuration.

The first time you connect, the Gajim XMPP client will offer to pin
the self-signed certificate. Alternatively, you may install the
Certificate Authority used to sign the certificate, into your
(preferably containerized) local trust store. (See
[certificate-ca](../_terminal/certificate-ca) for details and
caveats.)

Traefik is configured to support IP address filtering, in order to limit which
client and server addresses may connect to the XMPP services. See
`C2S_SOURCERANGE` and `S2S_SOURCERANGE` which are the client-to-server and
server-to-server XMPP protocol IP address ranges allowed, written in CIDR
format.

### Install

```
make install
```

Create one or more accounts:

```
make register
```

If you want to create a conference room:

```
make room
```

### Test login

Create a user with the helper.sh script as shown above. Copy the password it
prints out. Use Gajim to login with the JID and password. If using a self-signed
certificate, it will ask to pin the certificate the first time connecting
(confirm the certificate details upon connect by clicking the checkbox `Add this
certificate to the list of trusted certificates`, it may ask twice..)
