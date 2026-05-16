# llama.cpp

[llama.cpp](https://github.com/ggml-org/llama.cpp) is a high-performance
LLM inference engine written in C/C++. This service runs the
`llama-server` which provides an OpenAI-compatible API for serving
GGUF models.

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
execute tools itself. The consuming service (e.g., Open WebUI, Cursor,
or any external coding agent) must handle tool execution and return
results to the model.

#### Built-in Tools

llama.cpp also supports **built-in tools** that run inside the container
itself (via the `--tools` flag, controlled by `LLAMA_TOOLS`). These allow
llama.cpp's own web UI to act as a standalone assistant that can read/write
files and execute shell commands **inside the container**.

Available built-in tools: `read_file`, `write_file`, `edit_file`,
`apply_diff`, `exec_shell_command`, `file_glob_search`, `grep_search`.

**Built-in tools are disabled by default** (`LLAMA_TOOLS=`) because they
only have access to files inside the container (e.g., `/models/`). They
are not useful for external coding agents, which use the OpenAI-compatible
tool calling API instead — the agent executes tools on the host, and
llama.cpp only generates the tool call requests.

To enable built-in tools, set `LLAMA_TOOLS=all` in your `.env` file and
run `make reinstall`.

### Idle Model Unloading

llama.cpp can automatically unload models from GPU/RAM after a period of
inactivity to conserve resources. Any new request will automatically
trigger a reload.

```
LLAMA_SLEEP_IDLE_SECONDS=300
```

Set the number of seconds of idleness before the server enters sleep mode.
Leave blank to disable (models stay loaded until evicted by LRU).

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

Interactive multi-select menu to remove models from `/models/`. If the
models preset is enabled (`LLAMA_MODELS_PRESET_ENABLED=true`),
corresponding sections are also removed from `models.ini`.

After deleting a model that was currently loaded, run `make restart`
to update llama.cpp.

#### Manual Model Placement

You can also place `.gguf` files directly:
- **Host path**: Copy files to the path configured in `LLAMA_MODELS_HOST_PATH`
- **Docker volume**: Use `make shell` and download via `curl` inside the container

#### Per-Model INI Configuration

All model configurations are stored in a single `/models/models.ini`
file that the server reads at startup. Each section in the INI file
are custom configs for a model that exists in `/models/` as a .gguf file.

Example `models.ini`:

```ini
[llama3]
model = /models/llama-3-8b-instruct.Q5_K_M.gguf
ctx-size = 8192
ngl = 35
threads = 8

[mistral]
model = /models/mistral-7b-instruct-v0.3.Q4_K_M.gguf
ctx-size = 4096
ngl = 20
threads = 8

[qwen]
model = /models/qwen2.5-coder-7b-instruct.Q5_K_M.gguf
ctx-size = 16384
ngl = 35
threads = 8
```

##### Key config parameters

| Parameter  | What it controls |
|------------|------------------|
| `model`    | Absolute path to the GGUF file |
| `ctx-size` | Context window size in tokens. Larger values use more VRAM. |
| `ngl`      | Number of GPU layers offloaded. Set to `0` for CPU-only; increase until you hit VRAM limits. |
| `threads`  | CPU threads for the layers that remain on CPU. |

##### Managing Model Configurations

```
make manage-model-configs
```

This target provides an interactive wizard that:

1. Lists all models and prompts you to select one
2. Downloads `models.ini` from container if it exists, or creates a new blank file
3. Opens the file in your `$EDITOR` (falls back to `nano` if unset)
4. Validates the INI syntax before uploading
5. Saves the edited file back to `/models/models.ini` in the container

##### Manual Configuration

You can also edit `models.ini` directly in the `/models/` directory
(on the host or inside the container). After adding or updating the
INI file, restart the service:

```
make restart
```

**Important:** llama.cpp reads the preset file at startup only — it
does not hot-reload it. Changes require a restart to take effect.

##### Disabling the preset file

Set `LLAMA_MODELS_PRESET_ENABLED=false` in your `.env` file to disable
the `--models-preset` flag. Models will still be auto-discovered via
`--models-dir`, but without per-model configuration.

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
