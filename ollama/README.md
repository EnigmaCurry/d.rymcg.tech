# Ollama

[Ollama](https://github.com/ollama/ollama) is a local LLM
runtime/engine that lets you run and interact with language models via
simple API endpoints.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{DOCKER_CONTEXT}_{INSTANCE}`.

Edit the `OLLAMA_CONTEXT_LENGTH` variable to set the default context
length for models you load. (The default is `4096` which is set
conservatively low.)

### Authentication and Authorization

You may add an API token to secure your service by setting
`OLLAMA_API_TOKEN` in the `.env_{CONTEXT}_{INSTANCE}` file.

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

## Install

```
make install
```

## Using Ollama

There is no web frontend to Ollama. You use it via its REST API. You
can `make shell` to enter a shell in the Ollama container and use it
via its CLI ([here is a CLI
reference](https://github.com/ollama/ollama?tab=readme-ov-file#cli-reference)),
or you can use it via API calls ([here is the API
documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)).

## Destroy

```
make destroy
```

This completely removes the container and deletes all its volumes.
