# Node-RED

[Node-RED](https://nodered.org/) is a programming tool for wiring together
hardware devices, APIs and online services in new and interesting ways.

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `NODERED_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `NODERED_HTTP_AUTH` - HTTP Basic Authentication Password hashed with
   htpasswd.
 
Node-RED does not provide any authentication, so Traefik can limit access via
HTTP Basic Authentication, which requires a username and password for access.
The password must be hashed with the `htpasswd` utility, and then saved in the
.env file.

Create a random password hash for a given username:

```
## Create a random password hash for the given user ..
## ( ) creates a subshell, so the envrionment stays clean..
## To do it, copy/paste all of this as-is into your BASH shell.
(
 read -p "Enter the username: " USERNAME
 echo "Hashing password ... wait just a sec ..."
 PLAIN_PASSWORD=$(openssl rand -base64 30 | head -c 20)
 HASH_PASSWORD=$(echo $PLAIN_PASSWORD | docker run -i --rm httpd:2.4 htpasswd -inB ${USERNAME})
 echo "Username: ${USERNAME}"
 echo "Plain text password: ${PLAIN_PASSWORD}"
 echo "Hashed user/password: ${HASH_PASSWORD}"
 URL_ENCODED=https://${USERNAME}:$(python -c "from urllib.parse import quote; print(quote('''${PLAIN_PASSWORD}'''))")@example.com/...
 echo "Url encoded: ${URL_ENCODED}"
)
```

Copy the hashed user/password text and paste into the `.env` variable
`NODERED_HTTP_AUTH`. Start the container with `docker-compose up -d` then login
to the app with the username `admin` and the plain text password.

