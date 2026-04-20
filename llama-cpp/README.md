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

Place `.gguf` model files in this directory. You can:

1. **Load a model at startup** by setting `LLAMA_INITIAL_MODEL` to the
   path inside the container (e.g., `/models/model.gguf`).

2. **Switch models via API** without restarting the container. Use the
   llama.cpp server API to load a different model from the `/models`
   directory.

3. **Use from consuming services** like Open WebUI by pointing them at
   the llama.cpp API endpoint. Model switching is handled by the
   consuming service.

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
