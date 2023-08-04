# homepage

[homepage](https://github.com/benphelps/homepage) is a modern (fully static,
fast), secure (fully proxied), highly customizable application dashboard
with integrations for more than 25 services and translations for over 15
languages.

## Config

```
make config
```

This will ask you to enter the domain name to use, and whether or not
you want to configure a username/password via HTTP Basic Authentication.
It automatically saves your responses into the configuration file
`.env_{DOCKER_CONTEXT}`.

You customize your Homepage dashboard by editing `.yaml` files in the `config`
directory, then running `make install`. There is not a way to customize your
dashboard from within the Homepage UI.

Copy each of the `*.yaml-dist` files in the `config` directory, removing
`-dist` from the new files' names (e.g., copy `config/services.yaml-dist`
to `config/services.yaml`), then edit the files. You can view configuration
documentation [here](https://gethomepage.dev/en/configs/services/).

Homepage will install a sample file for any configuration file you don't
customize, so if you plan not to use one of the files, you should customize
it by saving it with no content.

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the password if you enabled it (and chose to store it in
`passwords.json`).

## Destroy

```
make destroy
```

This completely removes the container and all its volumes.
