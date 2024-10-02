# Homepage

[Homepage](https://github.com/benphelps/homepage) is a modern (fully static,
fast), secure (fully proxied), highly customizable application dashboard
with integrations for more than 25 services and translations for over 15
languages.

## Config

```
make config
```

This will ask you to enter the main domain name to use for homepage,
as well as a secondary domain name to use for webhooks.

It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

By default (when HOMEPAGE_AUTO_CONFIG=true), Homepage will automatically be
configured for all your d.rymcg.tech apps running on the current Docker
context. To update the Homepage configuration whenever your running
d.rymcg.tech apps change, you will need to run `make config` and
`make install` in the `homepage` directory.

When HOMEPAGE_AUTO_CONFIG=false, Homepage will be configured an external
template repository configurable by setting `HOMEPAGE_TEMPLATE_REPO` in your
`.env_{INSTANCE}` file. A template repo can be forked from
[github.com/EnigmaCurry/d.rymcg.tech_homepage-template](https://github.com/EnigmaCurry/d.rymcg.tech_homepage-template)
to create your own custom Homepage configuration, and this container can be
configured to automatically pull from your fork, and to trigger an automatic
rebuild/redeploy on git push via webhook. Your fork can be a public or
private repository. (Tested on gitea and github).

Homepage has support for loading information from the docker socket,
but this has been turned off by default for security reasons, if you
wish to enable this support, answer the question posed by `make config`
and/or set `HOMEPAGE_ENABLE_DOCKER=true` in your `.env_{INSTANCE}`
file.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Generate deploy key (if using a private template repository)

Before you install, if `HOMEPAGE_AUTO_CONFIG=false` and you have customized
`HOMEPAGE_TEMPLATE_REPO` and have set it to a private git repository, you will
need to create an SSH deploy key in order to be able to clone it automatically:

```
make git-deploy-key
```

This will generate and save a new SSH key in the config volume
(`/app/config/ssh/id_rsa`). It will print out the public key, which
you need to copy and paste into your Gitea, Github, or Gitlab
repository settings (Search for Deploy Key in the settings, and add
this public key to allow cloning from the private repository.)

![2023-08-07T00:40:50,971689020-06:00](https://github.com/EnigmaCurry/d.rymcg.tech/assets/43061/2b74a83f-27ff-4a74-8614-060775dcfacf)

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
`passwords.json`). You may bookmark the link it prints out and that 
way you can store the username and password in your browser or to share
it with someone else.

## Destroy

```
make destroy
```

This completely removes the container and all of the data, including the Git deploy key.

## Reloading Webhook (optional)

You can optionally enable automatic reloading of your config whenever
you make pushes to your template git repository. Your git host can
send a webhook request back to your homepage instance, to tell it to
restart and reload the config.

First you must enable `HOMEPAGE_TEMPLATE_REPO_SYNC_ON_START=true` in
your `.env_{INSTANCE}` file. Note that this will *delete* your
existing config, and redownload the template repository on *each*
restart of the container.

Second you must configure your Gitea, Github, or Gitlab repository to
add the webhook.

 * Webhook URL is of the format: `https://homepage.example.com/reloader/restart`
 * Choose the data type: `application/json`
 * Webhook Secret is found in your `.env_{INSTANCE}` as
   `HOMEPAGE_RELOADER_HMAC_SECRET`. This secret is used to validate
   that the request is actually coming from your git host.
 * No extra authorization header is required.

![2023-08-07T00:39:36,722487208-06:00](https://github.com/EnigmaCurry/d.rymcg.tech/assets/43061/5a0001c3-505d-4984-a114-a9bd1f8ea33b)

