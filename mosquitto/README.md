# Mosquitto

[Mosquitto](https://mosquitto.org/) is an MQTT pub/sub message broker.
This is a hardened configuration that uses Mutual TLS with
[Step-CA](../step-ca) and per-context ACL.

Example use cases:

 * Use it in combination with [node-red](../nodered) to create easy task
automation pipelines.
 * Use it in combination with [minio](../minio) to respond to S3 bucket
events (lambda)
 * Write code for an embedded arduino microcontroller (e.g., ESP32) to
   publish sensor data.

## Deploy Step-CA

Mosquitto is configured to require Mutual TLS:

 * Follow the [Step-CA README](../step-ca) to `config` and `install`
   your CA server (it does not need to be on the same machine, but it
   can be).
 * Set `STEP_CA_AUTHORITY_POLICY_X509_ALLOW_DNS` to include the list
   of allowed domains:
   
   * The domain of the MQTT server, e.g., `mqtt.example.com` (this
     could also be a wildcard if you have other services too.)
   * The wildcard domain for the MQTT clients, e.g.,
     `*.clients.mqtt.example.com`
   * Put all of the rules together in the Step-CA env file as a comma
     separated list. Set:
     `STEP_CA_AUTHORITY_POLICY_X509_ALLOW_DNS=mqtt.example.com,*.clients.mqtt.example.com`

 * Come back here as soon as you have run the Step-CA `make install`
   command. This README will give you the instructions specific to
   mosquitto.
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
make -C ~/git/vendor/enigmacurry/d.rymcg.tech/step-ca/ client-bootstrap

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

 * `MOSQUITTO_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `MOSQUITTO_STEP_CA_URL` the root URL of your Step-CA instance
   (e.g., `https://ca.example.com`)
 * The `MOSQUITTO_STEP_CA_TOKEN` will be automatically set, but you
   will need to enter your root Step-CA credentials to get it.

## Configure ACL

By default, no user can read or write to any topic. Rules must be
added to the per-context ACL file (`acl.conf`) in
[config/template/context](config/template/context) directory. Use
[acl.example.conf](config/template/acl.example.conf) as an example.
The template is re-rendered each time the mosquitto service is
restarted.

The client usernames are the same as the TLS cert Common Name (CN) or
domain name (e.g., `foo.clients.mqtt.example.com`). The ACL `pattern`
rule directive can substitute `%c` or `%u`, they are both equivalent,
and they resolve to the client's Common Name.

```
## Example ACL for the user foo.clients.mqtt.example.com :
## user foo can read or write these topics:
user foo.clients.mqtt.example.com
topic readwrite sensors/temperature
topic readwrite devices/doorbell

## Example ACL for the user bar.clients.mqtt.example.com :
## user bar can only read the same topics:
user bar.clients.mqtt.example.com
topic read sensors/temperature
topic read devices/doorbell
```

Be aware that mqtt clients receive no positive feedback on whether or
not they have access to a topic. If the client connects (with a valid
TLS cert), and then subscribes to a channel that it is denied access
to, it will still appear to have connected to that topic, but it will
essentially be connected to dead space. No messages can be sent or
received unless the ACL allows it.

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

Make sure you see the `step-cli` container issue the certificate.

```
### Example log excerpt showing certificate exists:
step-cli-1   | 2025-01-22T04:31:34.305555158Z ✔ Certificate: /home/step/certs/mqtt.example.com.crt
step-cli-1   | 2025-01-22T04:31:34.305910540Z ✔ Private Key: /home/step/certs/mqtt.example.com.key
```

## Test mosquitto clients

Install the mosquitto package on your workstation:

```
## on Fedora:
sudo dnf install mosquitto
```

Create a certificate for your mosquitto client:

```
make cert
```

 * Enter the `subject (CN / domain name) to be certified`: this should
   be a unique sub domain name for your client. It can be made up, and
   does not need DNS. Example: `foo.clients.mqtt.example.com`. It is
   recommended to use your workstation hostname for the first part.

Subscribe to the test channel:

```
(
HOST=mqtt.example.com
CN=foo.clients.mqtt.example.com
CA_CERT=certs/root_ca.crt
CERT=certs/${CN}.crt
KEY=certs/${CN}.key
PORT=8883
TOPIC=test

mosquitto_sub \
  -h ${HOST} \
  --cert ${CERT} \
  --key ${KEY} \
  --cafile ${CA_CERT} \
  -p ${PORT} \
  -t ${TOPIC}
)
```


In a second terminal, publish to the test channel:

```
(
HOST=mqtt.example.com
CN=foo.clients.mqtt.example.com
CA_CERT=certs/root_ca.crt
CERT=certs/${CN}.crt
KEY=certs/${CN}.key
PORT=8883
TOPIC=test

mosquitto_pub \
  -h ${HOST} \
  --cert ${CERT} \
  --key ${KEY} \
  --cafile ${CA_CERT} \
  -p ${PORT} \
  -t ${TOPIC} \
  -m "Hello, World."
)
```


## Increasing TLS certificate validation period

Every TLS certificate is designed to expire at some point. If you can
automate the renewal, having a short expiration is desirable from a
security perspective. Sometimes its inconvenient to update TLS
certificates, for example if you program embedded devices you usually
flash the certificate into the device ROM along with your software.
Manually renewing certificates for 100 embedded devices is not exactly
fun.

The mosquitto server certificate will be renewed automatically by the
[step-cli](step-cli) sidecar container. You can similarly setup a
step-cli cron job to maintain any other certificates:

```
## This is how any client can renew their own certificate.
## A client must renew their certificate *before* it expires!
## Put this into a cronjob
step-cli ca renew --force CRT_FILE KEY_FILE
```

For embedded devices, you will still probably need to generate/renew
certificates by hand via `make cert` and redeploy them.

Choose a certificate expiration time that is a balance between
convenience and security. [.env-dist](.env-dist) contains the default
setting `MOSQUITTO_CLIENT_CERT_EXPIRATION_HOURS=2160`, which sets the
client certificate expiration to 90 days (via `make cert`).

2160 hours is also the default MAX setting for Step-CA. If you want to
have expiration times longer than this you must edit the Step-CA .env
file as well:

```
## Set Step-CA MAX expiration to 100 years:
make -C ~/git/vendor/enigmacurry/d.rymcg.tech/step-ca \
    reconfigure var=STEP_CA_AUTHORITY_CLAIMS_MAX_TLS_CERT_DURATION=876582h
make -C ~/git/vendor/enigmacurry/d.rymcg.tech/step-ca install
```

Setting a certificate to expire in 100 years is more convenient for
devices you want to install and forget, but its also pretty insecure
given the passage of time. What happens if you lose possession of your
certificate key? If that happens to you five years from now, an
attacker can still use that valid key for another 95 years AND they
can renew the certificate indefinitely!

Thankfully, you can simply disable access to a given key via the ACL:

```
# Deny access to a specific user by not defining any rules
user alice.clients.mqtt.example.com

```

The certificate will still be valid (until it expires), but it won't
be able to read or write to any topic.

You can also prevent the certificate from being renewed (passive
revocation):

```
CERT=certs/foo.clients.mqtt.example.com.crt
SERIAL=$(cat $CERT | \
              step certificate inspect --format json | \
              jq -r .serial_number)
echo "Going to revoke cert with serial # ${SERIAL}"
step ca revoke ${SERIAL} --provisioner admin --reason "Key compromise"
```

**Passive revocation only prevents the certificate from being renewed,
it does NOT revoke the current certificate.**
