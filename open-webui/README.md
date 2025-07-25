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

## Exposing Ollama

Ollama is a local LLM runtime/engine that lets you run and interact
with language models via simple API endpoints. Open-WebUI is a
front-end that lets you interact with language models served by Ollama for
(and others). By default, this installs an Ollama container and an
Open-WebUI container, and the Ollama container is accessible only by
the Open-WebUI container. Running `make config` will ask you if you
want to expose the Ollama container to be able to access it from other
apps or services, and if so, what domain you want Traefik to forward
to it and what IP Source range(s) you want to be able to access it.

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

This completely removes the container and deletes all its volumes.
