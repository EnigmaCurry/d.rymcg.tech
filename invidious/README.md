# Invidious

[Invidious](https://github.com/iv-org/invidious) is an alternative front-end to
YouTube.

This install assumes you want a private instance, protected by
username/password. If not, comment out the `Authentication` section in the
`docker-compose.yaml`.

## Create username/password

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

Paste the Hashed user/password into your `.env` file for the `INVIDIOUS_HTTP_AUTH` variable.

## Notes on invidious

The default setting is for clients to stream videos directly from Google. If
this is not desired, make sure you set the setting in the client interface
called `Proxy videos`. Also see [invidious docs on
this](https://github.com/iv-org/documentation/blob/master/Always-use-%22local%22-to-proxy-video-through-the-server-without-creating-an-account.md).
