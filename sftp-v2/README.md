# sftp

This is a fork of [atmoz/sftp](https://github.com/atmoz/sftp), which is more
secure by default: 
 * It allows only SSH keys, no password authentication allowed.
 * All data is stored in named volumes.
 * Automatically imports SSH public keys from the provided GitHub username
(instead of password field).
 * Stores `authorized_keys` in a directory outside the user's chroot
(`/etc/ssh/keys/$USER_authorized_keys`).

## Setup

 * Copy `.env-dist` to `.env`, and edit the `SFTP_PORT` and `SFTP_USERS`
   variables.
 * Examine [docker-compose.yaml](docker-compose.yaml)
 * Deploy with `docker-compose up -d`

## Mounting data inside another container

All of the user data is stored in a docker named volume: `sftp_sftp-data`. In
order to access the same data from another container, mount the same volume
name. For example, with the username `ryan`:

```
docker run --rm -it -v sftp_sftp-data:/data debian ls -lha /data/ryan
```
