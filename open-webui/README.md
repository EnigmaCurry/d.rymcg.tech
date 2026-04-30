# Open WebUI

[Open WebUI](https://github.com/open-webui/open-webui?tab=readme-ov-file)
is an extensible, feature-rich, and user-friendly self-hosted AI
platform designed to operate entirely offline. It supports various LLM
runners like Ollama and OpenAI-compatible APIs, with built-in
inference engine for RAG, making it a powerful AI deployment solution.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{DOCKER_CONTEXT}_{INSTANCE}`.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

If you enable OAuth2 authentication, open-webui accounts will be
created automatically for any successfully logged in user, based upon
the email address forwarded from traefik-forward-auth
`X-Forwarded-User`.

You must immediately log in, the first user to authenticate will
become the admin automatically.

### Custom CSS

Optionally, you can create your own CSS stylesheet to customize
Open-WebUI's appearance (remember to append the `!important`
declaration to ensure your custom styles take precedence over
Open-WebUI's internal style sheets). Save your custom CSS file in this
project's directory and name the file `custom.css`.

If make changes to your `custom.css` file, run `make update-css` to
upload it to the container and restart the Open-WebUI service.

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser.

## Destroy

```
make destroy
```

This completely removes the container and deletes all its volumes.
