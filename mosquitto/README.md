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

You must install the `mosquitto` client package with the same version
(`MOSQUITTO_VERSION` in your .env file), so it is easiest to run a
container for testing:

```
## Create a shell with mosquitto client (same version) installed:
make client
```

Subscribe to a topic:

```
PASSWORD=your_admin_password
mosquitto_sub -h mqtt.example.com -p 8883 -u admin -P ${PASSWORD} -t test
```

In another terminal, publish to the topic:
```
PASSWORD=your_admin_password
mosquitto_pub -h mqtt.example.com -p 8883 -u admin -P ${PASSWORD} -t test -m "test message"
```

