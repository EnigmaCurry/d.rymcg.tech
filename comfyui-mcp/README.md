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

## Using your own image

Upload the file, then import it. The import becomes an ordinary job, so
everything below applies to it exactly as to a generated sprite:

```
make upload FILE=sketch.png
# {"image_id":"f3d4958c84a8","width":1024,"height":1024,...}
```

```
import_image(image_id="f3d4958c84a8", label="my sketch")  -> job 4b3d
refine_pixel_art("4b3d", "give the wizard large feathered wings")
```

Uploads deliberately go through a side channel rather than a tool argument.
An image passed as base64 in a tool call travels through the calling model's
context window, which costs on the order of 350k tokens per megabyte. The
endpoint is the same one `make upload` calls, and it takes the same bearer
token as the MCP endpoint:

```
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -F file=@sketch.png https://comfyui-mcp.example.com/upload
```

Uploaded images are normalized on arrival: converted to RGB and scaled so
the long edge matches the working resolution. Anything under 256px is
enlarged with nearest neighbour, so existing pixel art keeps its hard edges
rather than being blurred on the way in. Proportions are preserved
throughout, so a 2:1 image becomes a 2:1 sprite.

Unimported uploads are swept after `COMFYUI_MCP_UPLOAD_TTL` (24h by
default). Once imported, the job holds its own copy and the TTL no longer
applies.

## Refining

`refine_pixel_art` applies a corrective instruction to an existing sprite:
"remove the sword", "make the eyes blue", "give it a red hat". It chains
from the parent job's stored **full-resolution** render, not from the
quantized sprite, because re-encoding a 16-colour 64x64 image would compound
loss on every round. The result is then downscaled and quantized with the
parent's settings, so the style carries over.

Refinement deliberately uses a different model from generation. Plain
img2img on the SDXL pipeline re-renders the whole frame under a new prompt;
it handles "darker" or "more detail" but not "remove the sword". Qwen-Image-
Edit interprets the instruction relative to the source image, so localized
corrections actually land.

Each refine creates a new child job and leaves the parent untouched, so you
can iterate, branch, or go back:

```
generate_pixel_art("a green slime monster")   -> job a1b2
refine_pixel_art("a1b2", "give it a crown")   -> job c3d4
refine_pixel_art("c3d4", "make it angry")     -> job e5f6
refine_pixel_art("a1b2", "give it a hat")     -> job g7h8  (branches from the original)
```

## Prerequisites

The [comfyui](../comfyui) project must already be installed **on the same
Docker context**, with these models installed.

For generation:

- An SDXL checkpoint, e.g. `albedobaseXL_v21.safetensors` (`checkpoints`)
- The pixel art LoRA, `pixel-art-xl.safetensors` (`loras`)

For refinement:

- `qwen_image_edit_2509_fp8_e4m3fn.safetensors` (`diffusion_models`, ~19GB)
- `qwen_2.5_vl_7b_fp8_scaled.safetensors` (`text_encoders`)
- `qwen_image_vae.safetensors` (`vae`)

Install models from the `comfyui` directory with `make add-models`. For the
pixel art LoRA, use model type `loras` and this URL:

```
https://huggingface.co/nerijs/pixel-art-xl/resolve/main/pixel-art-xl.safetensors
```

For the edit model, use model type `diffusion_models` and:

```
https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors
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
| `generate_pixel_art` | Generate a sprite from a prompt. Blocks until done unless `wait=false`. |
| `import_image` | Turn an uploaded image into a sprite job you can then refine. |
| `refine_pixel_art` | Apply a corrective instruction to an existing job, returning a child job. |
| `get_job_status` | Check a job, returning the image once it has finished. |
| `list_jobs` | List recent jobs, newest first, showing refinement lineage. |
| `get_job_image` | Re-fetch a previous image, native size or magnified preview. |

`generate_pixel_art` takes `prompt` plus optional `negative_prompt`, `size`
(8-256, default 64), `colors` (2-256, default 16), `seed`, `steps`, `cfg`,
`lora_strength`, `resample` (`nearest` or `box`), `view_scale`, and `wait`.

The string `pixel art` is prepended to every prompt, so describe just the
subject: `a knight in silver armor holding a sword, side view`.

`refine_pixel_art` takes `job_id` and `instruction`, plus optional `size`,
`colors`, `seed`, `steps`, `cfg` (default 2.5; higher tends to over-apply
the edit), `view_scale` and `wait`. Size, palette and preview scale default
to the parent job's.

Generation takes a couple of seconds once SDXL is resident; a refinement
takes appreciably longer, since the edit model is a separate ~19GB load and
will evict the other from VRAM when you alternate between them.

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
