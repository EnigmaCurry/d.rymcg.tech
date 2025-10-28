# Homepage

[Homepage](https://github.com/gethomepage/homepage) is a highly
customizable application dashboard with integrations for more than 25
services and translations for over 15 languages.

## Config

```
make config
```

This will ask you to enter the main domain name to use for homepage,
as well as a secondary domain name to use for webhooks.

It automatically saves your responses into the configuration file
`.env_{DOCKER_CONTEXT}_{INSTANCE}`.

The configuration for your Homepage instance is contained in an
external repository that you must fork from the provided template
repository. Set `HOMEPAGE_TEMPLATE_REPO` in your
`.env_{DOCKER_CONTEXT}_{INSTANCE}` file. The template repo can be
forked from
[github.com/EnigmaCurry/d.rymcg.tech_homepage-template](https://github.com/EnigmaCurry/d.rymcg.tech_homepage-template)
to create your own custom Homepage configuration, this container will
automatically pull from your fork on startup, and to trigger an
automatic rebuild/redeploy on git push via webhook. Your fork can be a
public or private repository. (Tested on forgejo and github).

Homepage has support for loading information from the docker socket,
which has been enabled by default. If you wish to disable this
support, answer the question posed by `make config` and/or set
`HOMEPAGE_ENABLE_DOCKER=false` in your
`.env_{DOCKER_CONTEXT}_{INSTANCE}` file.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Generate deploy key (if using a private template repository)

```
make git-deploy-key
```

This will generate and save a new SSH key in the config volume
(`/app/config/ssh/id_rsa`). It will print out the public key, which
you need to copy and paste into your Forgejo, Github, or Gitlab
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

This completely removes the container and all of the data, including
the Git deploy key.

## Reloading Webhook

Your config will be automatically reloaded whenever you make pushes to
your template git repository. Your git host must be configured to send
a webhook request back to your homepage instance, to tell it to
restart and reload the config.

Note that this will *delete* your existing config and redownload the
template repository on *each* restart of the container.

Configure your Forgejo, Github, or Gitlab repository to add the
webhook.

 * Webhook URL is of the format: `https://homepage-webhook.example.com/reloader/restart`
 * Choose the data type: `application/json`
 * Webhook Secret is found in your `.env_{DOCKER_CONTEXT}_{INSTANCE}`
   as `HOMEPAGE_RELOADER_HMAC_SECRET`. This secret is used to validate
   that the request is actually coming from your git host.
 * No extra authorization header is required.

![2023-08-07T00:39:36,722487208-06:00](https://github.com/EnigmaCurry/d.rymcg.tech/assets/43061/5a0001c3-505d-4984-a114-a9bd1f8ea33b)

