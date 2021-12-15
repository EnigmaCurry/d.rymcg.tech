# matterbridge

[Matterbridge](https://github.com/42wim/matterbridge) is a bridge between many
different message platforms ("mattermost, IRC, gitter, xmpp, slack, discord,
telegram, rocketchat, twitch, ssh-chat, zulip, whatsapp, keybase, matrix,
microsoft teams, nextcloud, mumble, vk and more")

If you need to install Certificate Authorities for certificates that your
message servers use, copy them to the `matterbridge/matterbridge/certs`
directory. For instance, if you created a Certificate Authority with the
included [cert-manger.sh](../certificate-ca):

```
../certificate-ca/cert-manager.sh get_ca > ./matterbridge/certs/local-certificate-ca.pem
```

Copy the `.env-dist` to `.env` and edit the variables for your config.

Start the bridge:

```
docker-compose up --build -d
```
