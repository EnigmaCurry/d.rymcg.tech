# Mosquitto

[Mosquitto](https://mosquitto.org/) is an MQTT pub/sub message broker.
This is a hardened configuration that uses Mutual TLS with
[Step-CA](../step-ca) and per-context ACL.

Example use cases:

 * Use it in combination with [node-red](../nodered) to create easy task
automation pipelines.
 * Use it in combination with [minio](../minio) to respond to S3 bucket
events (lambda)

## Deploy Step-CA

Mosquitto is configured to require Mutual TLS via
[Step-CA](../step-ca):

 * Follow the [Step-CA README](../step-ca) to `config` and `install`
   your CA server (it does not need to be on the same machine, but it
   can be).
 * Set `STEP_CA_AUTHORITY_POLICY_X509_ALLOW_DNS` to include the list
   of allowed domains:
   
   * The domain of the MQTT server, e.g., `mqtt.example.com`
   * The domains for the MQTT clients, e.g.,
     `*.clients.mqtt.example.com`
   * In the Step-CA .env file, set
     `STEP_CA_AUTHORITY_POLICY_X509_ALLOW_DNS=mqtt.example.com,*.clients.mqtt.example.com`
 * Come back here as soon as you have run the Step-CA `make install`
   command. This README will give you the instructions specific to
   mosquitto.
 * ACME is not required for this scenario (one-time-use API tokens
   will be issued instead).

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


