# llama.cpp

[llama.cpp](https://github.com/ggml-org/llama.cpp) is a high-performance
LLM inference engine written in C/C++. This service runs the
`llama-server` which provides an OpenAI-compatible API for serving
GGUF models.

## Config

```
make config
```

This will ask you to enter the domain name to use, select the GPU
profile (cpu/cuda/rocm), choose the image variant (server/full/light),
and configure model storage. It automatically saves your responses
into the configuration file `.env_{DOCKER_CONTEXT}_{INSTANCE}`.

### Image Variants

- **server** - Only `llama-server` (smallest, recommended for API-only use)
- **full** - `llama-server` + model conversion tools + quantization tools
- **light** - `llama-server` + `llama-cli` (minimal)

### Authentication and Authorization

You may add an API token to secure your service by setting
`LLAMA_API_TOKEN` in the `.env_{CONTEXT}_{INSTANCE}` file.

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

## Install

```
make install
```

## Using llama.cpp

llama.cpp server provides an OpenAI-compatible REST API and includes a
built-in web UI for model selection and chat. Access the web UI at
`https://{LLAMA_TRAEFIK_HOST}`.

### API Documentation

- [llama.cpp server API](https://github.com/ggml-org/llama.cpp/blob/master/docs/server/README.md)
- [OpenAI-compatible API](https://github.com/ggml-org/llama.cpp/blob/master/docs/server/usage.md)

### Tool Calling and Web Search

Function/tool calling is enabled by default via the `--jinja` flag
(`LLAMA_JINJA=true`). This allows consuming services like Open WebUI
to use tool calling for features like web search, code execution, and
more.

Note that llama.cpp only **generates tool call requests** — it does not
execute tools itself. The consuming service (e.g., Open WebUI) must
handle tool execution and return results to the model.

### Model Management

Models are stored in the `/models` directory inside the container,
which is backed by either a Docker volume or a host path (configured
via `LLAMA_MODELS_HOST_PATH`).

The server runs in **router mode** with `--models-dir /models`, which
auto-discovers all `.gguf` files. Models are evicted using LRU when
`LLAMA_MODELS_MAX` is reached.

**Important:** The model file changes (adding or deleting `.gguf` files)
are **not automatically detected** by llama.cpp at runtime. After adding
or removing models, you must restart the service for llama.cpp to
recognize the changes:

```
make restart
```

A [model reload endpoint](https://github.com/ggml-org/llama.cpp/issues/21779)
is being developed upstream that will allow llama.cpp to rescan its models
directory without a restart. Once available, this will be integrated into
the model management targets.

#### Adding Models

```
make add-models
```

Prompts you for model sources. Supports:
- **Direct URLs**: `https://huggingface.co/user/repo/resolve/main/model.gguf`
- **HF identifier with file**: `user/repo:filename.gguf`
- **HF identifier alone**: `user/repo` (lists available `.gguf` files to choose from)

For gated/private models, set `LLAMA_HF_TOKEN` in your `.env` file.

After downloading, run `make restart` to make the new model available
in llama.cpp.

#### Listing Models

```
make list-models
```

Lists all `.gguf` files in `/models/`, one per line, with their model
ID (filename without extension):

```
Bonsai-1.7B-Q1_0.gguf (Bonsai-1.7B-Q1_0)
Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf (Qwen3.6-35B-A3B-UD-Q8_K_XL)
```

For JSON output (from the llama.cpp API, showing only loaded models):

```
make list-models-json
```

#### Deleting Models

```
make delete-models
```

Interactive multi-select menu to remove models from `/models/`.

After deleting, run `make restart` if the deleted model was currently
loaded in memory.

#### Manual Model Placement

You can also place `.gguf` files directly:
- **Host path**: Copy files to the path configured in `LLAMA_MODELS_HOST_PATH`
- **Docker volume**: Use `make shell` and download via `curl` inside the container

### Shell Access

```
make shell
```

Enter the container shell to run `llama-cli`, `llama-quantize`, or
other tools (available depending on the image variant selected).

## Destroy

```
make destroy
```

This completely removes the container and deletes all its volumes.
