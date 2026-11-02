# ComfyUI Pixel Art MCP

An [MCP](https://modelcontextprotocol.io) server that turns an existing
[ComfyUI](../comfyui) deployment into a pixel art generator for AI
assistants (Claude Code, Claude Desktop, or any other MCP client).

## How it generates pixel art

A pixel art LoRA on its own produces images that *look* pixelated but are
still full resolution, with anti-aliased edges and thousands of colours.
This service runs a two stage pipeline to get real sprite output:

1. An SDXL checkpoint with the
   [pixel-art-xl](https://huggingface.co/nerijs/pixel-art-xl) LoRA renders
   at 1024x1024.
2. The result is downscaled onto a true pixel grid (nearest neighbour by
   default) and quantized to a small palette with dithering disabled.

The returned preview is magnified with nearest neighbour so it is legible in
a chat client; the sprite is also kept at its native size (64x64 and the
like) and can be fetched with `get_job_image(job_id, native=true)`.

## Prerequisites

The [comfyui](../comfyui) project must already be installed **on the same
Docker context**, and must have both models installed:

- An SDXL checkpoint, e.g. `albedobaseXL_v21.safetensors`
- The pixel art LoRA, `pixel-art-xl.safetensors`

Install models from the `comfyui` directory with `make add-models`. For the
LoRA, use model type `loras` and this URL:

```
https://huggingface.co/nerijs/pixel-art-xl/resolve/main/pixel-art-xl.safetensors
```

Note the `/resolve/` in that URL. A Hugging Face `/blob/` URL returns the
web page for the file rather than the file itself, and ComfyUI will later
fail with `The safetensors header is too large`.

## Config

```
make config
```

This asks for the domain name, the ComfyUI Docker network and URL, and
which checkpoint and LoRA to use. It saves them to
`.env_{DOCKER_CONTEXT}_{INSTANCE}`.

The default ComfyUI URL is `http://comfyui-cuda:8188`. The hostname is the
ComfyUI *compose service* name, which depends on its GPU profile —
`comfyui-cuda`, `comfyui-rocm`, `comfyui-intel`, or `comfyui-cpu`. The
default network name is `comfyui_default`; confirm with `docker network ls`.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication
on top of your app.

This endpoint controls a GPU, so do not leave it open to the internet.

`make config` offers to generate an API token (`COMFYUI_MCP_API_TOKEN`),
following the same pattern as the [vllm](../vllm) project. When set, the
server rejects any request without a matching
`Authorization: Bearer <token>` header. This is the recommended protection
here, because unlike HTTP Basic Auth it is understood by MCP clients
natively, and unlike OAuth2 it needs no browser.

The standard `COMFYUI_MCP_IP_SOURCERANGE`, HTTP Basic Auth, and mTLS options
from [AUTH.md](../AUTH.md) are also available and compose with the token.
OAuth2 via traefik-forward-auth is wired up but is usually a poor fit, since
MCP clients are not browsers and generally cannot complete an interactive
login redirect.

## Install

```
make install
```

## Connect a client

Print the endpoint URL:

```
make url
```

Register it with Claude Code, passing the API token:

```
claude mcp add --transport http pixel-art \
  "$(make -s url)" \
  --header "Authorization: Bearer $(../_scripts/dotenv -f .env_$(../_scripts/docker_context)_default get COMFYUI_MCP_API_TOKEN)"
```

Or spelled out:

```
claude mcp add --transport http pixel-art https://comfyui-mcp.example.com/mcp \
  --header "Authorization: Bearer YOUR_TOKEN"
```

If you left the token blank, drop the `--header` argument.

## Tools

| Tool | Purpose |
|---|---|
| `generate_pixel_art` | Generate a sprite. Blocks until done unless `wait=false`. |
| `get_job_status` | Check a job, returning the image once it has finished. |
| `list_jobs` | List recent jobs, newest first. |
| `get_job_image` | Re-fetch a previous image, native size or magnified preview. |

`generate_pixel_art` takes `prompt` plus optional `negative_prompt`, `size`
(8-256, default 64), `colors` (2-256, default 16), `seed`, `steps`, `cfg`,
`lora_strength`, `resample` (`nearest` or `box`), `view_scale`, and `wait`.

The string `pixel art` is prepended to every prompt, so describe just the
subject: `a knight in silver armor holding a sword, side view`.

## Logs

```
make logs
```

## Uninstall

```
make uninstall
```

To also delete the stored job history and generated sprites:

```
make destroy
```
