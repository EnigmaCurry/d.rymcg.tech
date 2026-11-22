# vLLM

[vLLM](https://github.com/vllm-project/vllm) is a high-throughput LLM
inference engine with an OpenAI-compatible API server.

This is a [d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech)
project. If you are new to d.rymcg.tech, make sure to read the
[main README.md](../README.md) first.

## Config

```
make config
```

This will ask you to enter the domain name, GPU type, model name, and
other settings. It automatically saves your responses into the
configuration file `.env_{DOCKER_CONTEXT}_{INSTANCE}`.

### GPU Selection

During configuration you will be asked to choose between CUDA (Nvidia
GPUs) and ROCm (AMD GPUs). This selects the appropriate Docker
Compose profile and container configuration.

### Container Image

By default vLLM uses the pre-built
[vllm/vllm-openai](https://hub.docker.com/r/vllm/vllm-openai) image.
You can set `VLLM_IMAGE` during configuration to use a different
image or tag.

### Authentication and Authorization

You may add an API token to secure your service by setting
`VLLM_API_TOKEN` in the `.env_{CONTEXT}_{INSTANCE}` file.

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

### HuggingFace Token

If you need to serve gated or private models, set `VLLM_HF_TOKEN` to
your HuggingFace access token.

### Trust Remote Code

Some models require custom Python code from their HuggingFace
repository to load. If you see an error about `trust_remote_code`,
set `VLLM_TRUST_REMOTE_CODE=true` in your env file.

Before enabling this, you should review the model's custom code on
HuggingFace (look for `modeling_*.py`, `configuration_*.py`, and
`tokenization_*.py` files):

```
https://huggingface.co/MODEL_ORG/MODEL_NAME/tree/main
```

### Models Host Path

Set `VLLM_MODELS_HOST_PATH` to a directory on the host to persist
downloaded models there. If left blank, models are stored in a named
Docker volume.

### Max Model Length

Set `VLLM_MAX_MODEL_LEN` to limit the maximum context length. Leave
blank to use the model's default.

### Tool Calling

Tool calling is enabled by default (`VLLM_ENABLE_AUTO_TOOL_CHOICE=true`).
vLLM will auto-detect the correct parser for your model. To override
the parser, set `VLLM_TOOL_CALL_PARSER` (e.g. `hermes`,
`llama3_json`, `mistral`, `qwen3_xml`). See the [vLLM tool calling
docs](https://docs.vllm.ai/en/latest/features/tool_calling.html)
for supported parsers.

### Reasoning Parser

Set `VLLM_REASONING_PARSER` to enable structured reasoning output
(e.g. `deepseek_r1`).

### Prefix Caching

Set `VLLM_ENABLE_PREFIX_CACHING=true` to enable automatic prefix
caching, which can speed up repeated prompts with shared prefixes.

### Tensor Parallelism

Set `VLLM_TENSOR_PARALLEL_SIZE` to split a model across multiple
GPUs. The default is 1 (single GPU).

## Install

```
make install
```

### Served Model Name

Set `VLLM_SERVED_MODEL_NAME` to create an alias for the model name.
This is required for Claude Code integration since model names
containing `/` (e.g. `Qwen/Qwen3-0.6B`) are not supported by Claude
Code. For example, set it to `qwen3` to serve the model under that
name.

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

## Claude Code Integration

vLLM implements the [Anthropic Messages
API](https://docs.vllm.ai/en/latest/serving/integrations/claude_code/),
so you can use it as a backend for [Claude
Code](https://docs.anthropic.com/en/docs/claude-code/overview)
instead of the Anthropic API.

### Requirements

Your model must have strong tool calling capabilities. Tool calling is
enabled by default in this configuration
(`VLLM_ENABLE_AUTO_TOOL_CHOICE=true`).

### Setup

1. Set `VLLM_SERVED_MODEL_NAME` to a name without `/` characters
   (e.g. `qwen3` instead of `Qwen/Qwen3-0.6B`).

2. Launch Claude Code with environment variables pointing to your vLLM
   server:

```
ANTHROPIC_BASE_URL=https://vllm.example.com \
ANTHROPIC_API_KEY=xxxxxxx \
ANTHROPIC_AUTH_TOKEN=xxxxxxx \
ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3 \
ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3 \
ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3 \
claude
```

If you configured `VLLM_API_TOKEN`, use that value for
`ANTHROPIC_API_KEY` instead of `xxxxxxx`.

You can add these variables to your shell profile or to
`~/.claude/settings.json` for convenience.

## Destroy

```
make destroy
```

This completely removes the container and deletes all its volumes.
