# ssh-chat

## Add administrator key

The SSH key for the administrator should exist in `/root/.ssh/authorized_keys`
and `/root/.ssh/whitelist_keys`.

Add your local host SSH public key to the container administrator account:

```
cat ~/.ssh/id_rsa.pub | docker run --rm -v ssh-chat_root:/root -i -a stdin alpine sh -c "cat >> /root/.ssh/authorized_keys"
cat ~/.ssh/id_rsa.pub | docker run --rm -v ssh-chat_root:/root -i -a stdin alpine sh -c "cat >> /root/.ssh/whitelist_keys"
```

## Add other keys

Add other non-admin users' pubkeys to `/root/.ssh/whitelist_keys`:

```
GITHUB_USERNAME=enigmacurry
curl https://github.com/${GITHUB_USERNAME}.keys | docker run --rm -v ssh-chat_root:/root -i -a stdin alpine sh -c "cat >> /root/.ssh/whitelist_keys"
```
