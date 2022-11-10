# SFTP

This is a fork of [atmoz/sftp](https://github.com/atmoz/sftp), which is more
secure by default:
 * It allows only SSH keys, no password authentication allowed.
 * Automatically imports SSH public keys from a webserver with
   `ssh-import-id` (using GitHub, Launchpad, or custom URL).
 * Stores `authorized_keys` in a directory outside the user's chroot
(`/etc/ssh/keys/$USER_authorized_keys`).
 * All data is stored in named volumes.

### Setup

 * Run `make config` to create the default `.env_${DOCKER_CONTEXT}` file.
 * Edit the `SFTP_PORT`, `SFTP_USERS`, and `KEYFILE_URL` variables in
   the `.env_${DOCKER_CONTEXT}` file.
 * Run `make install`.

### Mounting data inside another container

All of the user data is stored in a docker named volume: `sftp_sftp-data`. In
order to access the same data from another container, mount the same volume
name. For example, with the username `ryan`:

```
docker run --rm -it -v sftp_sftp-data:/data debian ls -lha /data/ryan
```
