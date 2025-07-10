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
`.env_{INSTANCE}`.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

```
make install
```

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

This completely removes the container (and would also delete all its
volumes; but `whoami` hasn't got any data to store.)
