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

There is no web frontend to llama.cpp server. You use it via its REST
API, which is OpenAI-compatible.

### API Documentation

- [llama.cpp server API](https://github.com/ggml-org/llama.cpp/blob/master/docs/server/README.md)
- [OpenAI-compatible API](https://github.com/ggml-org/llama.cpp/blob/master/docs/server/usage.md)

### Model Management

Models are stored in the `/models` directory inside the container,
which is backed by either a Docker volume or a host path (configured
via `LLAMA_MODELS_HOST_PATH`).

The server runs in **router mode** with `--models-dir /models`, which
auto-discovers all `.gguf` files. Models are evicted using LRU when
`LLAMA_MODELS_MAX` is reached.

**Choosing how to load models:**

- **Set `LLAMA_INITIAL_MODEL`** in your `.env` file to a specific model
  path (e.g., `/models/model.gguf`). This model loads at startup.
  To change models later, you must edit `LLAMA_INITIAL_MODEL` in your
  `.env` file and run `make reinstall` — this restarts the container
  with the new model.

- **Leave `LLAMA_INITIAL_MODEL` blank** to start without any model
  pre-loaded. You can then switch between all downloaded models on the
  fly — no restart or reinstall needed. Select models from the
  llama.cpp web UI dropdown or via the `/models/load` API endpoint.

#### Adding Models

```
make add-models
```

Prompts you for model sources. Supports:
- **Direct URLs**: `https://huggingface.co/user/repo/resolve/main/model.gguf`
- **HF identifier with file**: `user/repo:filename.gguf`
- **HF identifier alone**: `user/repo` (lists available `.gguf` files to choose from)

For gated/private models, set `LLAMA_HF_TOKEN` in your `.env` file.

#### Listing Models

```
make list-models
```

Shows all `.gguf` files in `/models/` with sizes, plus what the API reports.

#### Deleting Models

```
make delete-models
```

Interactive multi-select menu to remove models from `/models/`.

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
