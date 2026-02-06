# vLLM

[vLLM](https://github.com/vllm-project/vllm) is a high-throughput LLM
inference engine with an OpenAI-compatible API server.

## Config

```
make config
```

This will ask you to enter the domain name, GPU type, model name, and
other settings. It automatically saves your responses into the
configuration file `.env_{DOCKER_CONTEXT}_{INSTANCE}`.

### Authentication and Authorization

You may add an API token to secure your service by setting
`VLLM_API_TOKEN` in the `.env_{CONTEXT}_{INSTANCE}` file.

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

### HuggingFace Token

If you need to serve gated or private models, set `VLLM_HF_TOKEN` to
your HuggingFace access token.

### Models Host Path

Set `VLLM_MODELS_HOST_PATH` to a directory on the host to persist
downloaded models there. If left blank, models are stored in a named
Docker volume.

## Install

```
make install
```

## Using vLLM

vLLM exposes an OpenAI-compatible API. You can use it with any OpenAI
client library by pointing it to your vLLM domain:

```
curl https://vllm.example.com/v1/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -d '{
    "model": "Qwen/Qwen3-0.6B",
    "prompt": "Hello, world!",
    "max_tokens": 100
  }'
```

You can `make shell` to enter a shell in the vLLM container.

## Destroy

```
make destroy
```

This completely removes the container and deletes all its volumes.
