# Mosquitto

[Mosquitto](https://mosquitto.org/) is an MQTT pub/sub message broker. 

Example use cases:

 * Use it in combination with [node-red](../nodered) to create easy task
automation pipelines.
 * Use it in combination with [minio](../minio) to respond to S3 bucket
events (lambda)

## Deploy Step-CA

Mosquitto is configured to use Mutual TLS via [Step-CA](../step-ca):

 * Follow the README to `config` and `install` your
   [Step-CA](../step-ca) instance (it does not need to be on the same
   server, but can be).
 * Set `STEP_CA_AUTHORITY_POLICY_X509_ALLOW_DNS` to the list of
   allowed domains, which must include:
   
   * The MQTT server domain, e.g., `mqtt.example.com`
   * The MQTT client domains, e.g., `*.clients.mqtt.example.com`
   * `STEP_CA_AUTHORITY_POLICY_X509_ALLOW_DNS=mqtt.example.com,*.clients.mqtt.example.com`
   
 * You do not need to create any certificates or clients by hand.
 * ACME is not required for this scenario (tokens will be used
   instead).

Your workstation needs to have the `step-cli` tool installed, and it
needs to be bootstrapped to connect to your Step-CA server instance.

```
## Use either method:

## Method 1: use the step-ca Makefile target:
## (you may have already done this if you installed Step-CA on the same machine)
make -C ~/git/vendor/enigmacurry/d.rymcg.tech/step-ca/ client-bootstrap

## Method 2: if you want to do it manually from a new machine:
FINGERPRINT=$(curl -sk https://ca.rymcg.tech/roots.pem | \
  docker run --rm -i smallstep/step-cli step certificate fingerprint -)
step-cli ca bootstrap --ca-url https://ca.rymcg.tech --fingerprint ${FINGERPRINT}

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
 * The `MOSQUITTO_STEP_CA_TOKEN` will be automatically set.

## Install

Run:

```
make install
```

## Test it

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

Connect to the test channel:

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
