# Mosquitto
[Mosquitto](https://mosquitto.org/) is an MQTT pub/sub message broker. 


You can use it in combination with [node-red](../nodered) to create easy task
automation pipelines.

You can use it in combination with [minio](../minio) to respond to S3 bucket
events (lambda)

## Background

Good blog posts:

 * [S-MQTTT, or: secure-MQTT-over-Traefik](https://jurian.slui.mn/posts/smqttt-or-secure-mqtt-over-traefik/)
 * [MQTT – How to use ACLs and multiple user accounts](https://blog.jaimyn.dev/mqtt-use-acls-multiple-user-accounts/)

## Config

Run `make config` or copy `.env-dist` to `.env`, and edit variables accordingly.

 * `MOSQUITTO_TRAEFIK_HOST` the external domain name to forward from traefik.
 
Before starting mosquitto, create the user accounts you need:

```
make admin
```

The `admin` password will be printed to the terminal. 

You can add additional users and print their passwords: 

```
make user
```

List all the user accounts:

```
make list-users
```

## Run

Start mosquitto with `make install` or `docker-compose up -d`

## Test it

Install the `mosquitto` client package with your package manager.

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

