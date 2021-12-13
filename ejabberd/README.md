# ejabberd

[ejabberd](https://github.com/processone/ejabberd) is an XMPP server written in
erlang.

Since Traefik does not understand the XMPP protocol, TLS must be handled by the
service container (ejabberd) directly. In this configuration, Traefik forwards
raw TCP port 5222 to the ejabberd container, which handles TLS via STARTTLS
(this is the preferred automatic protocol that Gajim supports, allowing login
without needing to click to Advanced Settings).

This ejabberd configuration *will not* share the main TLS certificate used by
Traefik. In this case, a self-signed certificate needs to be created just for
ejabberd use:

```
EJABBERD_HOST=xmpp.example.com
../certificate-ca/cert-manager.sh build
../certificate-ca/cert-manager.sh create_ca
../certificate-ca/cert-manager.sh create ${EJABBERD_HOST}
```

`cert-manager.sh` will have created a new self-signed certificate, signed by the
`local-certificate-ca` local to your docker instance. The certificate and key is
stored in a volume created by `cert-manager.sh` in order to be mounted by the
ejabberd container. The volume created for the example above, would be named:
`local-certificate-ca_xmpp.example.com`, with the certificates found inside that
are valid for 100 years. The Gajim XMPP client will offer users to pin the
self-signed certificate, the first time you connect. Alternatively, you may
install the Certificate Authority used to sign the certificate, into your local
trust store:

```
# Export the Certificate Authority:
../certificate-ca/cert-manager.sh get_ca
```

Traefik is configured to support IP address filtering, to limit which client and
server addresses may connect to the XMPP services. See `C2S_SOURCERANGE` and
`S2S_SOURCERANGE` which are the client-to-server and server-to-server XMPP
protocol IP address ranges allowed, written in CIDR format.

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
