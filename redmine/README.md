# Redmine

[Redmine](https://github.com/redmine/redmine) is a flexible project management
web application.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

This will also create a directory that you can use to install Redmine
plugins - the directory will be named `plugins_{CONTEXT}_{INSTANCE}`.
Ignore the directory if you don't plan on installing plugins.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

```
make install
```

The default login is "admin" with the password "admin" - you will be asked to
change the password on your initial login.

### Plugins

Optional: To install Redmine plugins, copy the unzipped plugin
directory into the `plugins_{CONTEXT}_{INSTANCE}` directory, then run
`make install-plugins` to copy them into the Redmine container, install
them, and restart the Redmine container.

Uninstalling a plugin must be done manually. The steps might include:
1) deleting the plugin directory from `/usr/src/redmine/plugins/` in
the Redmine container 
2) rolling back any plugin migrations (if the plugin had any and
supports rollbacks)
3) cleanup (recompiling assets or clearing cache) if the plugin made
any changes to themes, assets, or configuration files
4) restarting the Redmine container

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it
(and chose to store it in `passwords.json`).

## Destroy

```
make destroy
```

This completely removes the container and volumes.
