# Mosquitto

[Mosquitto](https://mosquitto.org/) is an MQTT pub/sub broker. You can use it in combination with node-red
for sending/receiving messages. 

Good blog posts:

 * [S-MQTTT, or: secure-MQTT-over-Traefik](https://jurian.slui.mn/posts/smqttt-or-secure-mqtt-over-traefik/)
 * [MQTT – How to use ACLs and multiple user accounts](https://blog.jaimyn.dev/mqtt-use-acls-multiple-user-accounts/)

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `MOSQUITTO_TRAEFIK_HOST` the external domain name to forward from traefik.
 
Start mosquitto initially only using the default config: `docker-compose up -d`

Create an initial admin account in order to test with (_WARNING: `-c` will
overwrite any existing password file without confirmation, so in the future when
you want to create further accounts, do not use the `-c` parameter!_):

```
(
  USERNAME=admin
  PASSWORD=$(openssl rand -base64 24)
  docker exec -it mosquitto mosquitto_passwd -c -b /mosquitto/config/passwd ${USERNAME} ${PASSWORD}
  echo "Created password database, initial user account:"
  echo "username: ${USERNAME}"
  echo "password: ${PASSWORD}"
)
```

Copy the main config file, and the ACL config file, into the volume (you must do
this again in the future, anytime you modify these configs):

```
docker cp mosquitto.conf mosquitto:/mosquitto/config/mosquitto.conf
docker cp acl.conf mosquitto:/mosquitto/config/acl.conf
```

Restart mosquitto in order to reload the config:

```
docker-compose restart
```
