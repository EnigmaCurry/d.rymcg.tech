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
   `nats.example.com`). This is used as the TLS certificate CN.
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

## Configure authorization

Per-user subject authorization is configured via the `NATS_AUTH_USERS`
env var. With `verify_and_map`, NATS maps the client certificate's SAN
DNS name (e.g., `foo.clients.nats.example.com`) to a user entry.

Run `make auth-users` to interactively manage authorized users (this
is also called during `make config`). You can add, edit, and remove
users with an interactive menu.

The `NATS_AUTH_USERS` format is:

```
NATS_AUTH_USERS=CN:publish_subjects:subscribe_subjects;CN2:pub:sub
```

 * Entries separated by semicolons
 * Each entry: `CN:publish:subscribe`
 * Subjects within each field are comma-separated
 * Use `>` for all subjects
 * Leave publish or subscribe empty to deny that action
 * Empty `NATS_AUTH_USERS` = deny all (no users configured)

Examples:

```
## Full access for one user:
NATS_AUTH_USERS=foo.clients.nats.example.com:>:>

## Multiple users with different permissions:
NATS_AUTH_USERS=foo.clients.nats.example.com:>:>;bar.clients.nats.example.com::sensors.>

## Publish only (no subscribe):
NATS_AUTH_USERS=baz.clients.nats.example.com:events.>:
```

Unlisted users (those with a valid certificate but no entry in
`NATS_AUTH_USERS`) are denied all access by default.

Be aware that NATS clients receive no error when publishing to a
denied subject — the message is silently dropped. Similarly,
subscribing to a denied subject will succeed but no messages will be
received.

### JetStream and KV store permissions

When JetStream is enabled (`NATS_JETSTREAM_ENABLE=true`), the
publish/subscribe permissions also control access to JetStream
streams, KV buckets, and object stores. NATS implements these features
on top of regular subjects, so the same authorization model applies:

 * **KV get** requires **subscribe** permission on `$KV.BUCKET_NAME.>`
 * **KV put/delete** requires **publish** permission on `$KV.BUCKET_NAME.>`
 * **JetStream API** access requires both publish and subscribe on `$JS.API.>`

For full JetStream and KV access, grant `>` for both publish and
subscribe. For more granular control, grant permissions on specific
`$KV.` and `$JS.API.` subjects.

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
CN=foo.clients.nats.example.com
export NATS_URL="tls://nats.example.com:4222"
export NATS_CA=certs/root_ca.crt
export NATS_CERT=certs/${CN}.crt
export NATS_KEY=certs/${CN}.key

nats sub test
)
```

In a second terminal, publish a message:

```
(
CN=foo.clients.nats.example.com
export NATS_URL="tls://nats.example.com:4222"
export NATS_CA=certs/root_ca.crt
export NATS_CERT=certs/${CN}.crt
export NATS_KEY=certs/${CN}.key

nats pub test "Hello, World."
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
