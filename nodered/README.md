# Node-RED

[Node-RED](https://nodered.org/) is a programming tool for wiring together
hardware devices, APIs and online services in new and interesting ways.

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `NODERED_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `NODERED_HTTP_AUTH` - HTTP Basic Authentication Password hashed with
   htpasswd.

## Create username/password

Node-RED does not provide any authentication, so Traefik can limit access via
HTTP Basic Authentication, which requires a username and password for access.
The password must be hashed with the `htpasswd` utility.

[See common instructions for generating htpasswd hashed password
strings](../traefik-htpasswd)

Paste the generated `Hashed user/password` into your `.env` file for the
`NODERED_HTTP_AUTH` variable.

## Start the container

Start the container with `docker-compose up -d` then login to the app with the
username `admin` and the plain text password generated.

