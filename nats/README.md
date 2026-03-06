# NATS

[NATS](https://nats.io/) is a high-performance messaging system for
cloud native applications, IoT, and microservices architectures. This
is a hardened configuration that uses Mutual TLS with
[Step-CA](../step-ca).

Example use cases:

 * Pub/sub messaging between microservices
 * Request/reply communication patterns
 * Event streaming and data pipelines
 * Use it in combination with [node-red](../nodered) for task
   automation

## Deploy Step-CA

NATS is configured to require Mutual TLS:

 * Follow the [Step-CA README](../step-ca) to `config` and `install`
   your CA server (it does not need to be on the same machine, but it
   can be).
 * When configuring Step-CA, set
   `STEP_CA_AUTHORITY_POLICY_X509_ALLOW_DNS` to list your allowed
   domains:

   * Include the domain of the NATS server, e.g., `nats.example.com`
     (this could also be a wildcard if you have other services that
     need certificates too.)
   * Include the wildcard domain for the NATS clients, e.g.,
     `*.clients.nats.example.com`
   * For example:
     `STEP_CA_AUTHORITY_POLICY_X509_ALLOW_DNS=nats.example.com,*.clients.nats.example.com`

 * Come back here as soon as you have run the Step-CA `make install`
   command. This README will give you the instructions specific to
   NATS.
 * ACME is not required for this scenario (one-time-use API tokens
   will be issued instead).

Your workstation needs to have the
[step-cli](https://smallstep.com/docs/step-cli/installation/) tool
installed (use your package manager), and it needs to be bootstrapped
to connect to your Step-CA server instance:

```
## Use either method:

## Method 1: use the step-ca Makefile target:
## (you may have already done this if you installed Step-CA on the same machine)
d.rymcg.tech make step-ca client-bootstrap

## Method 2: if you want to do it manually from a new machine:
FINGERPRINT=$(curl -sk https://ca.example.com/roots.pem | \
  docker run --rm -i smallstep/step-cli step certificate fingerprint -)
step-cli ca bootstrap --ca-url https://ca.example.com --fingerprint ${FINGERPRINT}

## Check the status (should print 'ok'):
step-cli health
```

## Config

Run:

```
make config
```

Set:

 * `NATS_TRAEFIK_HOST` the external domain name (e.g.,
   `nats.example.com`). This is used for the TLS certificate and for
   the HTTP monitoring endpoint routed through Traefik.
 * `NATS_CLUSTER_NAME` the NATS server/cluster name (default: `nats`).
 * `NATS_CLIENT_PORT` the host port for NATS client connections
   (default: `4222`).
 * `NATS_STEP_CA_URL` the root URL of your Step-CA instance
   (e.g., `https://ca.example.com`)
 * `NATS_STEP_CA_FINGERPRINT` the Step-CA fingerprint will be
   retrieved automatically from the URL you supplied. You should
   verify it is correct (use Step-CA's `make inspect-fingerprint`).
 * The `NATS_STEP_CA_TOKEN` is the one-time-use token that you
   need to get from Step-CA to request a new server certificate. It
   will be automatically set, but you will need to enter your root
   Step-CA credentials to get it.

## Install

Run:

```
make install
```

## Check logs

Run:

```
make logs
```

Make sure you see the `step-cli` container issue the certificate:

```
### Example log excerpt showing certificate exists:
step-cli-1   | ✔ Certificate: /home/step/certs/nats.example.com.crt
step-cli-1   | ✔ Private Key: /home/step/certs/nats.example.com.key
```

And the `nats` container should show:

```
nats-1       | ## Found full TLS certificate chain.
```

## HTTP Monitoring

The NATS HTTP monitoring endpoint is available through Traefik at
`https://nats.example.com`. You can check server status at:

 * `https://nats.example.com/varz` - general server information
 * `https://nats.example.com/connz` - connection information
 * `https://nats.example.com/subsz` - subscription information

Access to the monitoring UI can be protected with HTTP Basic Auth,
OAuth2, or mTLS via the Traefik middleware settings in the `.env`
file.

## Create client certificates

Install the [nats-cli](https://github.com/nats-io/natscli) tool on
your workstation.

Create a certificate for your NATS client:

```
make cert
```

 * Enter the `subject (CN / domain name) to be certified`: this should
   be a unique subdomain name for your client. It can be made up, and
   does not need DNS. Example: `foo.clients.nats.example.com`. It is
   recommended to use your workstation hostname for the first part.

## Test NATS clients

Subscribe to a subject in one terminal:

```
(
HOST=nats.example.com
CN=foo.clients.nats.example.com
CA_CERT=certs/root_ca.crt
CERT=certs/${CN}.crt
KEY=certs/${CN}.key
PORT=4222

nats sub test \
  -s "tls://${HOST}:${PORT}" \
  --tlscert ${CERT} \
  --tlskey ${KEY} \
  --tlsca ${CA_CERT}
)
```

In a second terminal, publish a message:

```
(
HOST=nats.example.com
CN=foo.clients.nats.example.com
CA_CERT=certs/root_ca.crt
CERT=certs/${CN}.crt
KEY=certs/${CN}.key
PORT=4222

nats pub test "Hello, World." \
  -s "tls://${HOST}:${PORT}" \
  --tlscert ${CERT} \
  --tlskey ${KEY} \
  --tlsca ${CA_CERT}
)
```

## TLS certificate renewal

The NATS server certificate is renewed automatically by the
[step-cli](step-cli) sidecar container.

Client certificates can be renewed on any machine that has
[step-cli](https://smallstep.com/docs/step-cli/installation/)
installed and bootstrapped to the same Step-CA server. Run this on the
client before the certificate expires:

```
## Put this into a cronjob on the client to auto-renew:
step-cli ca renew --force CRT_FILE KEY_FILE
```

**Important:** Renewal exchanges the current valid certificate for a
new one. If the certificate expires before you renew it, Step-CA will
reject the renewal and you will need to issue a fresh certificate with
a new one-time token (via `make cert`). Set up a cronjob to renew well
before expiration.

The default client certificate expiration is 90 days
(`NATS_CLIENT_CERT_EXPIRATION_HOURS=2160`).

If you need expiration times longer than 90 days, you must also
increase the Step-CA maximum:

```
## Set Step-CA MAX expiration to 100 years:
d.rymcg.tech make step-ca \
    reconfigure var=STEP_CA_AUTHORITY_CLAIMS_MAX_TLS_CERT_DURATION=876582h
d.rymcg.tech make step-ca install
```

## Revoking a client certificate

You can prevent a certificate from being renewed (passive revocation):

```
CERT=certs/foo.clients.nats.example.com.crt
SERIAL=$(cat $CERT | \
              step certificate inspect --format json | \
              jq -r .serial_number)
echo "Going to revoke cert with serial # ${SERIAL}"
step ca revoke ${SERIAL} --provisioner admin --reason "Key compromise"
```

**Passive revocation only prevents the certificate from being renewed,
it does NOT revoke the current certificate.**
