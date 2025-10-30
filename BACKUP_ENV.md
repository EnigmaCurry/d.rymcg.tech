## Backup .env files in d.rymcg.tech

Because the `.env` files contain secrets, they are to be excluded from
being committed to the git repository via `.gitignore`. However, you
may still wish to retain your configurations by making a backup. This
section will describe how to make a backup of all of your `.env` and
`passwords.json` files into a GPG encrypted tarball, and how to
clean/delete all of the plain text copies.

### Setup GPG

First you will need to setup a GPG key. You can do this from the same
workstation, or from a different computer entirely:

```
# Create gpg key (note the long ID it generates, second line after 'pub'):
gpg --gen-key

# Send your key to the public keyserver:
gpg --send-keys [YOUR_KEY_ID]
```

On the workstation you cloned this repository to, import this key:

```
# Import your key from the public keyserver:
gpg --receive-keys [YOUR_KEY_ID]
```

### Create encrypted backup

From the root directory of your clone of this repository, run:

```
make backup-env
```

The script will ask to add `GPG_RECIPIENT` to your
`.env_${DOCKER_CONTEXT}_default` file. Enter the GPG pub key ID value
for your key.

A new encrypted backup file will be created in the same directory
called something like
`./${DOCKER_CONTEXT}_environment-backup-2022-02-08--18-51-39.tgz.gpg`.
The `GPG_RECIPIENT` key is the *only* key that will be able to read
this encrypted backup file.

### Clean environment files

Now that you have an encrypted backup, you may wish to delete all of
the unencryped `.env` files. Note that you will not be able to control
your docker-compose projects without the decrypted .env files, but you
may restore them from the backup at any time.

To delete all the .env files, you could run:

```
## Make sure you have a backup of your .env files first:
make clean
```

### Restore .env files from backup

To restore from this backup, you will need your GPG private keys setup
on your worstation, and then run:

```
make restore-env
```

Enter the name of the backup file, and all of the `.env` and
`passwords.json` files will be restored to their original locations.
