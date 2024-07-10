# Calibre

[calibre-web](https://github.com/janeczku/calibre-web?tab=readme-ov-file)
is a web interface for [Calibre](https://calibre-ebook.com/) - an
ebook manager.

## Config

```
make config
```

It is recommended to turn on some form of sentry authorization (eg.
HTTP Basic auth or IP address filter) in front of the server, that way
you do not expose the initial default deployment, which includes the
pre-baked username and password necessary to login the first time:

 * Username: `admin`
 * Password: `admin123`
 
After you login, and change the default password, you can then
consider turning off the sentry authorization.

## Install

```
make install
```

## Open

```
make open
```

## Initial Config

Once you are logged in, there are additional steps to configure the
application correctly:

### Database Configuration

 * Choose `Location of Calibre Database`. Enter `/books`. Do not enter
   any other directory, otherwise your files may be saved incorrectly.
 * Click `Save`.
 
### Update Password

 * Click the user icon in the upper right corner
 * Enter a new password.
 * Click `Save`.
 
### Enable Upload

By default, there is no option to upload books, until you enable the
feature to do so.

 * Click the circular icon in the top right corner, this opens the
   Admin view.
 * Click `Edit Basic Configuration`.
 * Click `Feature Configuration`.
 * Click `Enable Uploads`.
 * Click `Save`.
 
### Use SFTP

To manage the books en-masse, use the [sftp](../sftp) container.
