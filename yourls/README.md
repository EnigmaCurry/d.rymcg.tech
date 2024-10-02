# YOURLS

[Yourls](https://github.com/YOURLS/YOURLS) allows you to run **Y**our **O**wn
**URL** **S**hortener which includes detailed stats, analytics, plugins, and
more.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

```
make install
```

### Plugins

There are many plugins available for YOURLS [here](https://github.com/YOURLS/awesome?tab=readme-ov-file#themes).
In addition to the standard plugins that YOURLS comes with, this instance
will install the following plugins automatically (you can decide whether to
activate them in the administration interface):
- Download Plugin
- Force Lowercase
- Change Password

Most plugins have a very simple installation process: just copy their
`plugin.php` (and possibly other files the plugin requires) into
`/var/www/html/user/plugins/<plugin_name>/` in the `yourls-yourls-1` container.
You can do this manually or via the "Download Plugin" plugin, which allows you
to do this from the UI.

Some plugins and themes require more manual installation or configuration
(e.g., unzipping files, moving files to the root html directory, entering an
API key).

## Open

```
make open
```

This will automatically open the page in your web browser, and will prefill
the HTTP Basic Authentication password if you enabled it (and chose to store
it in `passwords.json`).

### Admin Users

Running `make config` will ask you to create an admin user, which will have
admin access to your YOURLS instance (every other user will only be able to
create shortened URLs, if you allow them to). You can create additional admin
users by running `make add-admin-user`. You can also delete admin users by
running `make delete-admin-user`, and you can list the existing admin users
by running `make list-admin-users`.

## Destroy

```
make destroy
```

This completely removes the container and volumes.
