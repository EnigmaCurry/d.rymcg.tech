"""MCP server exposing ComfyUI as a pixel art generator.

Generation is a two stage pipeline: an SDXL checkpoint with the pixel-art-xl
LoRA renders at 1024x1024, then the result is downscaled onto a real pixel
grid and quantized to a small palette. The LoRA alone produces art that only
looks pixelated; the downscale is what makes it actually one-colour-per-pixel.
"""

from __future__ import annotations

import asyncio
import io
import json
import os
import random
import secrets
import time
import uuid
from dataclasses import dataclass, field, fields, asdict
from pathlib import Path
from typing import Any, Literal

import httpx
import uvicorn
from PIL import Image as PILImage
from mcp.server.fastmcp import Context, FastMCP, Image
from mcp.server.transport_security import TransportSecuritySettings
from starlette.datastructures import Headers
from starlette.requests import Request
from starlette.responses import JSONResponse, Response
from starlette.types import ASGIApp, Receive, Scope, Send


def _env(name: str, default: str) -> str:
    return os.environ.get(name, default).strip() or default


COMFYUI_URL = _env("COMFYUI_MCP_COMFYUI_URL", "http://comfyui-cuda:8188").rstrip("/")
CHECKPOINT = _env("COMFYUI_MCP_CHECKPOINT", "albedobaseXL_v21.safetensors")
LORA = _env("COMFYUI_MCP_LORA", "pixel-art-xl.safetensors")
DATA_DIR = Path(_env("COMFYUI_MCP_DATA_DIR", "/data"))
JOB_TIMEOUT = float(_env("COMFYUI_MCP_JOB_TIMEOUT", "600"))
MAX_HISTORY = int(_env("COMFYUI_MCP_MAX_HISTORY", "200"))
BASE_RESOLUTION = int(_env("COMFYUI_MCP_BASE_RESOLUTION", "1024"))
API_TOKEN = os.environ.get("COMFYUI_MCP_API_TOKEN", "").strip()

# Refinement uses a dedicated instruction-editing model. The SDXL pipeline
# above cannot do corrective edits: img2img re-renders the whole frame rather
# than acting on "remove the sword".
EDIT_MODEL = _env("COMFYUI_MCP_EDIT_MODEL", "qwen_image_edit_2509_fp8_e4m3fn.safetensors")
EDIT_TEXT_ENCODER = _env("COMFYUI_MCP_EDIT_TEXT_ENCODER", "qwen_2.5_vl_7b_fp8_scaled.safetensors")
EDIT_VAE = _env("COMFYUI_MCP_EDIT_VAE", "qwen_image_vae.safetensors")

# Uploads arrive out of band via POST /upload rather than as tool arguments.
# Base64 in a tool argument would pass the whole image through the calling
# model's context window, which costs roughly 350k tokens per megabyte.
UPLOAD_DIR_NAME = "uploads"
MAX_UPLOAD_BYTES = int(_env("COMFYUI_MCP_MAX_UPLOAD_BYTES", str(64 * 1024 * 1024)))
UPLOAD_TTL = float(_env("COMFYUI_MCP_UPLOAD_TTL", "86400"))

DEFAULT_NEGATIVE = (
    "blurry, soft, photo, 3d render, smooth gradient, jpeg artifacts, "
    "text, watermark, signature"
)

Resample = Literal["nearest", "box"]


@dataclass
class Job:
    id: str
    prompt: str
    negative_prompt: str
    size: int
    colors: int
    seed: int
    steps: int
    cfg: float
    lora_strength: float
    resample: str
    view_scale: int
    status: str = "queued"           # queued | running | completed | failed
    created_at: float = field(default_factory=time.time)
    finished_at: float | None = None
    comfy_prompt_id: str | None = None
    error: str | None = None
    kind: str = "generate"           # generate | refine
    parent_id: str | None = None     # job this was refined from
    instruction: str | None = None   # the corrective text, for refine jobs
    denoise: float = 1.0

    @property
    def sprite_path(self) -> Path:
        return DATA_DIR / f"{self.id}.png"

    @property
    def source_path(self) -> Path:
        """The full-resolution render, before downscaling.

        Refinement must chain from this rather than from the quantized sprite:
        re-encoding a 16-colour 64x64 image would compound loss every round.
        """
        return DATA_DIR / f"{self.id}.source.png"

    @property
    def view_path(self) -> Path:
        return DATA_DIR / f"{self.id}.view.png"

    @property
    def meta_path(self) -> Path:
        return DATA_DIR / f"{self.id}.json"

    def save(self) -> None:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        self.meta_path.write_text(json.dumps(asdict(self), indent=2))

    def summary(self) -> str:
        age = int(time.time() - self.created_at)
        line = (
            f"{self.id}  [{self.status}]  {self.size}x{self.size} "
            f"{self.colors}c  seed={self.seed}  {age}s ago"
        )
        if self.parent_id:
            line += f"\n    refined from {self.parent_id}: {(self.instruction or '')[:70]}"
        else:
            line += f"\n    {self.prompt[:90]}"
        if self.error:
            line += f"\n    error: {self.error}"
        return line


JOBS: dict[str, Job] = {}


def _load_jobs_from_disk() -> None:
    """Rebuild the job index after a restart so history survives redeploys."""
    if not DATA_DIR.is_dir():
        return
    for meta in sorted(DATA_DIR.glob("*.json")):
        try:
            data = json.loads(meta.read_text())
            known = {f.name for f in fields(Job)}
            job = Job(**{k: v for k, v in data.items() if k in known})
        except Exception:
            continue
        # A job still marked running cannot be resumed across a restart.
        if job.status in ("queued", "running"):
            job.status = "failed"
            job.error = "server restarted while job was in flight"
        JOBS[job.id] = job


def _prune_history() -> None:
    if len(JOBS) <= MAX_HISTORY:
        return
    for job in sorted(JOBS.values(), key=lambda j: j.created_at)[: len(JOBS) - MAX_HISTORY]:
        for p in (job.sprite_path, job.view_path, job.source_path, job.meta_path):
            p.unlink(missing_ok=True)
        JOBS.pop(job.id, None)


def build_workflow(job: Job) -> dict[str, Any]:
    """ComfyUI API-format graph: checkpoint -> LoRA -> sample -> decode -> save."""
    return {
        "1": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": CHECKPOINT},
        },
        "2": {
            "class_type": "LoraLoader",
            "inputs": {
                "lora_name": LORA,
                "strength_model": job.lora_strength,
                "strength_clip": job.lora_strength,
                "model": ["1", 0],
                "clip": ["1", 1],
            },
        },
        "3": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": f"pixel art, {job.prompt}", "clip": ["2", 1]},
        },
        "4": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": job.negative_prompt, "clip": ["2", 1]},
        },
        "5": {
            "class_type": "EmptyLatentImage",
            "inputs": {
                "width": BASE_RESOLUTION,
                "height": BASE_RESOLUTION,
                "batch_size": 1,
            },
        },
        "6": {
            "class_type": "KSampler",
            "inputs": {
                "seed": job.seed,
                "steps": job.steps,
                "cfg": job.cfg,
                "sampler_name": "euler_ancestral",
                "scheduler": "normal",
                "denoise": 1.0,
                "model": ["2", 0],
                "positive": ["3", 0],
                "negative": ["4", 0],
                "latent_image": ["5", 0],
            },
        },
        "7": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["6", 0], "vae": ["1", 2]},
        },
        "8": {
            "class_type": "SaveImage",
            "inputs": {"filename_prefix": f"pixelart/{job.id}", "images": ["7", 0]},
        },
    }


def build_edit_workflow(job: Job, uploaded_image: str) -> dict[str, Any]:
    """ComfyUI API-format graph for instruction-based editing.

    TextEncodeQwenImageEditPlus folds the reference image into the
    conditioning itself, so the instruction is interpreted relative to the
    source rather than as a fresh prompt. The sampler starts from the source
    latent, which is why denoise stays at 1.0 here without losing the image.
    """
    return {
        "1": {
            "class_type": "UNETLoader",
            "inputs": {"unet_name": EDIT_MODEL, "weight_dtype": "default"},
        },
        "2": {
            "class_type": "CLIPLoader",
            "inputs": {"clip_name": EDIT_TEXT_ENCODER, "type": "qwen_image"},
        },
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": EDIT_VAE}},
        "4": {"class_type": "LoadImage", "inputs": {"image": uploaded_image}},
        "5": {
            "class_type": "TextEncodeQwenImageEditPlus",
            "inputs": {
                "clip": ["2", 0],
                "prompt": job.instruction or "",
                "vae": ["3", 0],
                "image1": ["4", 0],
            },
        },
        "6": {
            "class_type": "TextEncodeQwenImageEditPlus",
            "inputs": {
                "clip": ["2", 0],
                "prompt": job.negative_prompt,
                "vae": ["3", 0],
                "image1": ["4", 0],
            },
        },
        "7": {"class_type": "VAEEncode", "inputs": {"pixels": ["4", 0], "vae": ["3", 0]}},
        "8": {
            "class_type": "KSampler",
            "inputs": {
                "seed": job.seed,
                "steps": job.steps,
                "cfg": job.cfg,
                "sampler_name": "euler",
                "scheduler": "simple",
                "denoise": job.denoise,
                "model": ["1", 0],
                "positive": ["5", 0],
                "negative": ["6", 0],
                "latent_image": ["7", 0],
            },
        },
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {
            "class_type": "SaveImage",
            "inputs": {"filename_prefix": f"pixelart/{job.id}", "images": ["9", 0]},
        },
    }


def _fit(src_w: int, src_h: int, longest: int) -> tuple[int, int]:
    """Scale to `longest` on the long edge, preserving aspect ratio."""
    if src_w >= src_h:
        return longest, max(1, round(longest * src_h / src_w))
    return max(1, round(longest * src_w / src_h)), longest


def pixelate(raw_png: bytes, job: Job) -> tuple[bytes, bytes]:
    """Downscale onto a true pixel grid and quantize. Returns (sprite, view).

    `job.size` is the longest edge. Generated renders are square so this is
    the same as before for them, but imported images keep their proportions
    instead of being squashed into a square.
    """
    src = PILImage.open(io.BytesIO(raw_png)).convert("RGB")
    resample = PILImage.NEAREST if job.resample == "nearest" else PILImage.BOX
    small = src.resize(_fit(src.width, src.height, job.size), resample)
    # Dithering scatters stray pixels and reads as noise at sprite scale.
    small = small.quantize(
        colors=job.colors,
        method=PILImage.Quantize.MEDIANCUT,
        dither=PILImage.Dither.NONE,
    ).convert("RGB")

    sprite_buf = io.BytesIO()
    small.save(sprite_buf, format="PNG")

    view = small.resize(
        (small.width * job.view_scale, small.height * job.view_scale),
        PILImage.NEAREST,
    )
    view_buf = io.BytesIO()
    view.save(view_buf, format="PNG")
    return sprite_buf.getvalue(), view_buf.getvalue()


async def run_job(job: Job, ctx: Context | None = None) -> None:
    job.status = "running"
    job.save()
    try:
        async with httpx.AsyncClient(base_url=COMFYUI_URL, timeout=60.0) as client:
            if job.kind == "refine":
                parent = JOBS.get(job.parent_id or "")
                if parent is None:
                    raise ValueError(f"parent job {job.parent_id} is gone")
                if not parent.source_path.exists():
                    raise ValueError(
                        f"parent job {job.parent_id} has no stored source render "
                        "(it predates source retention), so it cannot be refined"
                    )
                # ComfyUI's LoadImage reads from its input directory, so the
                # stored render has to be handed over first.
                upload = await client.post(
                    "/upload/image",
                    files={"image": (f"{job.id}.png", parent.source_path.read_bytes(), "image/png")},
                    data={"overwrite": "true"},
                )
                if upload.status_code != 200:
                    raise RuntimeError(
                        f"uploading the source image failed (HTTP {upload.status_code}): "
                        f"{upload.text[:300]}"
                    )
                info = upload.json()
                name = info["name"]
                if info.get("subfolder"):
                    name = f"{info['subfolder']}/{name}"
                graph = build_edit_workflow(job, name)
            else:
                graph = build_workflow(job)

            resp = await client.post("/prompt", json={"prompt": graph})
            if resp.status_code != 200:
                raise RuntimeError(
                    f"ComfyUI rejected the workflow (HTTP {resp.status_code}): "
                    f"{resp.text[:400]}"
                )
            submitted = resp.json()
            if submitted.get("node_errors"):
                raise RuntimeError(f"workflow node errors: {submitted['node_errors']}")
            job.comfy_prompt_id = submitted["prompt_id"]
            job.save()

            deadline = time.time() + JOB_TIMEOUT
            entry = None
            while time.time() < deadline:
                hist = (await client.get(f"/history/{job.comfy_prompt_id}")).json()
                if job.comfy_prompt_id in hist:
                    entry = hist[job.comfy_prompt_id]
                    break
                if ctx is not None:
                    await ctx.report_progress(
                        progress=min(0.95, (time.time() - job.created_at) / JOB_TIMEOUT)
                    )
                await asyncio.sleep(2)

            if entry is None:
                raise TimeoutError(f"job did not finish within {JOB_TIMEOUT:.0f}s")

            status = entry.get("status", {})
            if status.get("status_str") == "error":
                messages = status.get("messages", [])
                raise RuntimeError(f"ComfyUI reported an error: {json.dumps(messages)[:600]}")

            images = [
                im
                for out in entry.get("outputs", {}).values()
                for im in out.get("images", [])
            ]
            if not images:
                raise RuntimeError("ComfyUI finished but produced no image")

            im = images[0]
            raw = (
                await client.get(
                    "/view",
                    params={
                        "filename": im["filename"],
                        "subfolder": im.get("subfolder", ""),
                        "type": im.get("type", "output"),
                    },
                )
            ).content

        sprite, view = pixelate(raw, job)
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        job.source_path.write_bytes(raw)
        job.sprite_path.write_bytes(sprite)
        job.view_path.write_bytes(view)
        job.status = "completed"
    except Exception as exc:  # surfaced to the caller via job.error
        job.status = "failed"
        job.error = f"{type(exc).__name__}: {exc}"
    finally:
        job.finished_at = time.time()
        job.save()
        _prune_history()


def _upload_dir() -> Path:
    d = DATA_DIR / UPLOAD_DIR_NAME
    d.mkdir(parents=True, exist_ok=True)
    return d


def _sweep_uploads() -> None:
    """Drop uploads nobody imported. Imported ones are copied into the job."""
    cutoff = time.time() - UPLOAD_TTL
    for f in _upload_dir().glob("*.png"):
        try:
            if f.stat().st_mtime < cutoff:
                f.unlink(missing_ok=True)
        except OSError:
            pass


def normalize_for_edit(raw: bytes) -> bytes:
    """Put an arbitrary image into the shape the edit model expects.

    Scales the long edge to the working resolution and rounds both sides to a
    multiple of 16 for the VAE. Images smaller than 256px are enlarged with
    nearest neighbour, so existing pixel art keeps its hard edges instead of
    being blurred on the way in.
    """
    img = PILImage.open(io.BytesIO(raw))
    img.load()
    img = img.convert("RGB")
    w, h = _fit(img.width, img.height, BASE_RESOLUTION)
    w, h = max(16, w - w % 16), max(16, h - h % 16)
    enlarging = img.width < 256 and img.height < 256
    img = img.resize((w, h), PILImage.NEAREST if enlarging else PILImage.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


allowed_hosts = [h.strip() for h in os.environ.get("COMFYUI_MCP_ALLOWED_HOSTS", "").split(",") if h.strip()]
transport_security = (
    TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=allowed_hosts,
        allowed_origins=[f"https://{h}" for h in allowed_hosts],
    )
    if allowed_hosts
    else None
)

mcp = FastMCP(
    name="pixel-art",
    instructions=(
        "Generates pixel art sprites with ComfyUI (SDXL + pixel-art-xl LoRA, then "
        "downscaled to a real pixel grid and palette-quantized). Use "
        "generate_pixel_art for a single sprite; it blocks until the image is ready "
        "unless you pass wait=false, in which case poll get_job_status."
    ),
    host=_env("COMFYUI_MCP_HOST", "0.0.0.0"),
    port=int(_env("COMFYUI_MCP_PORT", "8000")),
    streamable_http_path=_env("COMFYUI_MCP_PATH", "/mcp"),
    transport_security=transport_security,
)


@mcp.custom_route("/upload", methods=["POST"])
async def upload_endpoint(request: Request) -> JSONResponse:
    """Accept an image out of band and return a handle for import_image.

    Auth is already enforced for this path by BearerTokenMiddleware, which
    wraps the whole app. Accepts either multipart/form-data (field "file" or
    "image") or a raw image body.
    """
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > MAX_UPLOAD_BYTES:
        return JSONResponse(
            {"error": f"image exceeds {MAX_UPLOAD_BYTES} bytes"}, status_code=413
        )

    content_type = request.headers.get("content-type", "")
    if content_type.startswith("multipart/form-data"):
        form = await request.form()
        part = form.get("file") or form.get("image")
        if part is None or isinstance(part, str):
            return JSONResponse(
                {"error": "expected a file in field 'file' or 'image'"}, status_code=400
            )
        raw = await part.read()
    else:
        raw = await request.body()

    if not raw:
        return JSONResponse({"error": "empty request body"}, status_code=400)
    if len(raw) > MAX_UPLOAD_BYTES:
        return JSONResponse(
            {"error": f"image exceeds {MAX_UPLOAD_BYTES} bytes"}, status_code=413
        )

    try:
        normalized = normalize_for_edit(raw)
    except Exception as exc:
        return JSONResponse(
            {"error": f"not a decodable image: {type(exc).__name__}: {exc}"},
            status_code=400,
        )

    image_id = uuid.uuid4().hex[:12]
    (_upload_dir() / f"{image_id}.png").write_bytes(normalized)
    _sweep_uploads()

    with PILImage.open(io.BytesIO(normalized)) as im:
        width, height = im.size
    return JSONResponse(
        {
            "image_id": image_id,
            "width": width,
            "height": height,
            "bytes": len(normalized),
            "next": f"import_image(image_id=\"{image_id}\")",
        }
    )


# structured_output=False: these return an Image alongside text, and the
# structured-content path cannot serialize Image. This routes the result
# through _convert_to_content, which handles it.
@mcp.tool(structured_output=False)
async def import_image(
    image_id: str,
    label: str = "",
    size: int = 64,
    colors: int = 16,
    resample: Resample = "nearest",
    view_scale: int = 8,
) -> list[Any]:
    """Turn an uploaded image into a sprite you can then refine.

    Upload the file first with `make upload FILE=path.png` (or POST it to
    /upload), which returns an image_id. This pixelates it and records it as
    an ordinary job, so refine_pixel_art works on the result exactly as it
    does on a generated sprite.

    Args:
        image_id: Handle returned by the upload endpoint.
        label: Optional description, shown in list_jobs. Also used as the
            prompt context if you later refine this image.
        size: Sprite longest edge in real pixels (8-256). Proportions of the
            uploaded image are preserved.
        colors: Palette size (2-256).
        resample: Downscale filter, "nearest" (crisp) or "box" (softer).
        view_scale: Magnification of the returned preview (1-32).
    """
    if not 8 <= size <= 256:
        raise ValueError("size must be between 8 and 256")
    if not 2 <= colors <= 256:
        raise ValueError("colors must be between 2 and 256")
    if not 1 <= view_scale <= 32:
        raise ValueError("view_scale must be between 1 and 32")

    upload = _upload_dir() / f"{image_id}.png"
    if not upload.exists():
        raise ValueError(
            f"No such upload: {image_id}. Uploads expire after "
            f"{int(UPLOAD_TTL / 3600)}h; upload the image again."
        )

    job = Job(
        id=uuid.uuid4().hex[:12],
        prompt=label or "imported image",
        negative_prompt="",
        size=size,
        colors=colors,
        seed=0,
        steps=0,
        cfg=0.0,
        lora_strength=0.0,
        resample=resample,
        view_scale=view_scale,
        kind="import",
        status="running",
    )
    JOBS[job.id] = job
    job.save()

    try:
        raw = upload.read_bytes()
        sprite, view = pixelate(raw, job)
        job.source_path.write_bytes(raw)
        job.sprite_path.write_bytes(sprite)
        job.view_path.write_bytes(view)
        job.status = "completed"
    except Exception as exc:
        job.status = "failed"
        job.error = f"{type(exc).__name__}: {exc}"
        raise RuntimeError(f"Import failed: {job.error}") from exc
    finally:
        job.finished_at = time.time()
        job.save()
        _prune_history()

    # The job owns its own copy now.
    upload.unlink(missing_ok=True)

    with PILImage.open(io.BytesIO(sprite)) as im:
        dims = f"{im.width}x{im.height}"
    return [
        Image(data=view, format="png"),
        f"Job {job.id}: imported as a {dims} sprite, {colors} colours. "
        f"Refine it with refine_pixel_art('{job.id}', '<instruction>').",
    ]


# structured_output=False: these return an Image alongside text, and the
# structured-content path cannot serialize Image. This routes the result
# through _convert_to_content, which handles it.
@mcp.tool(structured_output=False)
async def generate_pixel_art(
    prompt: str,
    ctx: Context,
    negative_prompt: str = DEFAULT_NEGATIVE,
    size: int = 64,
    colors: int = 16,
    seed: int | None = None,
    steps: int = 25,
    cfg: float = 7.0,
    lora_strength: float = 1.0,
    resample: Resample = "nearest",
    view_scale: int = 8,
    wait: bool = True,
) -> list[Any]:
    """Generate a pixel art sprite.

    Args:
        prompt: What to draw. "pixel art" is prepended automatically, so describe
            the subject (e.g. "a knight in silver armor holding a sword, side view").
        negative_prompt: What to avoid.
        size: Sprite edge length in real pixels (8-256). 32-64 reads as classic
            sprite work; 128 keeps more detail.
        colors: Palette size (2-256). 16 is a typical retro palette.
        seed: Fixed seed for reproducibility. Omit for a random one.
        steps: Sampler steps (1-100).
        cfg: Prompt adherence (1.0-20.0).
        lora_strength: Pixel-art LoRA weight (0.0-2.0). Above ~1.2 flattens detail.
        resample: Downscale filter. "nearest" keeps edges crisp and is the default;
            "box" averages, which is softer but steadier on noisy renders.
        view_scale: Nearest-neighbour magnification of the returned preview, so the
            sprite is legible. The saved sprite is always at native size.
        wait: Block until the image is ready. Set false to return a job id instead.
    """
    if not 8 <= size <= 256:
        raise ValueError("size must be between 8 and 256")
    if not 2 <= colors <= 256:
        raise ValueError("colors must be between 2 and 256")
    if not 1 <= steps <= 100:
        raise ValueError("steps must be between 1 and 100")
    if not 1.0 <= cfg <= 20.0:
        raise ValueError("cfg must be between 1.0 and 20.0")
    if not 0.0 <= lora_strength <= 2.0:
        raise ValueError("lora_strength must be between 0.0 and 2.0")
    if not 1 <= view_scale <= 32:
        raise ValueError("view_scale must be between 1 and 32")

    job = Job(
        id=uuid.uuid4().hex[:12],
        prompt=prompt,
        negative_prompt=negative_prompt,
        size=size,
        colors=colors,
        seed=seed if seed is not None else random.randint(0, 2**32 - 1),
        steps=steps,
        cfg=cfg,
        lora_strength=lora_strength,
        resample=resample,
        view_scale=view_scale,
    )
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    JOBS[job.id] = job
    job.save()

    if not wait:
        asyncio.create_task(run_job(job))
        return [
            f"Job {job.id} submitted (seed {job.seed}). "
            f"Poll get_job_status('{job.id}') for the result."
        ]

    await run_job(job, ctx)
    if job.status != "completed":
        raise RuntimeError(f"Generation failed: {job.error}")

    took = int((job.finished_at or time.time()) - job.created_at)
    return [
        Image(data=job.view_path.read_bytes(), format="png"),
        f"Job {job.id}: {size}x{size} sprite, {colors} colours, seed {job.seed}, "
        f"{took}s. Preview shown at {view_scale}x; native sprite saved as "
        f"{job.sprite_path.name} (fetch with get_job_image('{job.id}', native=true)).",
    ]


# structured_output=False: these return an Image alongside text, and the
# structured-content path cannot serialize Image. This routes the result
# through _convert_to_content, which handles it.
@mcp.tool(structured_output=False)
async def refine_pixel_art(
    job_id: str,
    instruction: str,
    ctx: Context,
    size: int | None = None,
    colors: int | None = None,
    seed: int | None = None,
    steps: int = 20,
    cfg: float = 2.5,
    view_scale: int | None = None,
    wait: bool = True,
) -> list[Any]:
    """Refine an existing sprite with a corrective instruction.

    Describe the change, not the whole scene: "remove the sword", "make the
    eyes blue", "give it a red hat". The instruction is applied to the stored
    full-resolution render of the parent job, then the result is downscaled
    and quantized exactly as the original was, so the sprite style carries
    over. The parent is left untouched and a new child job is returned, so you
    can refine repeatedly or branch from any earlier job.

    Args:
        job_id: The job to refine, from generate_pixel_art or a previous refine.
        instruction: The correction to apply.
        size: Override the sprite size. Defaults to the parent's.
        colors: Override the palette size. Defaults to the parent's.
        seed: Fixed seed for reproducibility. Omit for a random one.
        steps: Sampler steps (1-100).
        cfg: Instruction adherence (1.0-20.0). Around 2.5 suits this model;
            higher values tend to over-apply the edit and damage the image.
        view_scale: Magnification of the returned preview. Defaults to the parent's.
        wait: Block until the image is ready. Set false to return a job id.
    """
    parent = JOBS.get(job_id)
    if parent is None:
        raise ValueError(f"No such job: {job_id}")
    if parent.status != "completed":
        raise ValueError(f"Job {job_id} is {parent.status} and cannot be refined")
    if not parent.source_path.exists():
        raise ValueError(
            f"Job {job_id} has no stored source render, so it cannot be refined. "
            "Jobs generated before source retention was added are affected; "
            "regenerate it first."
        )
    if not instruction.strip():
        raise ValueError("instruction must not be empty")
    if not 1 <= steps <= 100:
        raise ValueError("steps must be between 1 and 100")
    if not 1.0 <= cfg <= 20.0:
        raise ValueError("cfg must be between 1.0 and 20.0")

    size = parent.size if size is None else size
    colors = parent.colors if colors is None else colors
    view_scale = parent.view_scale if view_scale is None else view_scale
    if not 8 <= size <= 256:
        raise ValueError("size must be between 8 and 256")
    if not 2 <= colors <= 256:
        raise ValueError("colors must be between 2 and 256")
    if not 1 <= view_scale <= 32:
        raise ValueError("view_scale must be between 1 and 32")

    job = Job(
        id=uuid.uuid4().hex[:12],
        prompt=parent.prompt,
        negative_prompt="",
        size=size,
        colors=colors,
        seed=seed if seed is not None else random.randint(0, 2**32 - 1),
        steps=steps,
        cfg=cfg,
        lora_strength=parent.lora_strength,
        resample=parent.resample,
        view_scale=view_scale,
        kind="refine",
        parent_id=parent.id,
        instruction=instruction,
    )
    JOBS[job.id] = job
    job.save()

    if not wait:
        asyncio.create_task(run_job(job))
        return [
            f"Refine job {job.id} submitted from {parent.id}. "
            f"Poll get_job_status('{job.id}') for the result."
        ]

    await run_job(job, ctx)
    if job.status != "completed":
        raise RuntimeError(f"Refinement failed: {job.error}")

    took = int((job.finished_at or time.time()) - job.created_at)
    return [
        Image(data=job.view_path.read_bytes(), format="png"),
        f"Job {job.id} (refined from {parent.id}): \"{instruction}\". "
        f"{size}x{size}, {colors} colours, seed {job.seed}, {took}s. "
        f"Refine again with refine_pixel_art('{job.id}', ...), or go back to "
        f"the original with refine_pixel_art('{parent.id}', ...).",
    ]


# structured_output=False: these return an Image alongside text, and the
# structured-content path cannot serialize Image. This routes the result
# through _convert_to_content, which handles it.
@mcp.tool(structured_output=False)
async def get_job_status(job_id: str) -> list[Any]:
    """Check a generation job, returning the image if it has finished.

    Args:
        job_id: Id returned by generate_pixel_art.
    """
    job = JOBS.get(job_id)
    if job is None:
        raise ValueError(f"No such job: {job_id}")
    if job.status == "completed" and job.view_path.exists():
        return [
            Image(data=job.view_path.read_bytes(), format="png"),
            job.summary(),
        ]
    return [job.summary()]


@mcp.tool()
async def list_jobs(limit: int = 20) -> str:
    """List recent generation jobs, newest first.

    Args:
        limit: How many jobs to show (1-100).
    """
    if not 1 <= limit <= 100:
        raise ValueError("limit must be between 1 and 100")
    jobs = sorted(JOBS.values(), key=lambda j: j.created_at, reverse=True)[:limit]
    if not jobs:
        return "No jobs yet."
    return f"{len(jobs)} job(s):\n\n" + "\n".join(j.summary() for j in jobs)


# structured_output=False: these return an Image alongside text, and the
# structured-content path cannot serialize Image. This routes the result
# through _convert_to_content, which handles it.
@mcp.tool(structured_output=False)
async def get_job_image(job_id: str, native: bool = False) -> list[Any]:
    """Re-fetch the image from a previous job.

    Args:
        job_id: Id returned by generate_pixel_art.
        native: Return the sprite at its true size (e.g. 64x64) instead of the
            magnified preview. Use this when you want the actual asset.
    """
    job = JOBS.get(job_id)
    if job is None:
        raise ValueError(f"No such job: {job_id}")
    if job.status != "completed":
        raise ValueError(f"Job {job_id} is {job.status}" + (f": {job.error}" if job.error else ""))
    path = job.sprite_path if native else job.view_path
    if not path.exists():
        raise ValueError(f"Image file for job {job_id} is missing")
    return [
        Image(data=path.read_bytes(), format="png"),
        f"Job {job_id} ({'native' if native else 'preview'}): {path.name}",
    ]


class BearerTokenMiddleware:
    """Require `Authorization: Bearer <token>` on every HTTP request.

    Written as raw ASGI rather than BaseHTTPMiddleware, which buffers responses
    and would break the streamable HTTP transport's long-lived SSE streams.
    """

    def __init__(self, app: ASGIApp, token: str) -> None:
        self.app = app
        self.expected = f"Bearer {token}"

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        # Lifespan and websocket scopes pass straight through.
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        presented = Headers(scope=scope).get("authorization", "")
        if not secrets.compare_digest(presented, self.expected):
            response = Response(
                "Unauthorized",
                status_code=401,
                headers={"WWW-Authenticate": "Bearer"},
            )
            await response(scope, receive, send)
            return
        await self.app(scope, receive, send)


def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    _load_jobs_from_disk()

    app: ASGIApp = mcp.streamable_http_app()
    if API_TOKEN:
        app = BearerTokenMiddleware(app, API_TOKEN)
    else:
        print(
            "WARNING: COMFYUI_MCP_API_TOKEN is blank - this endpoint requires no "
            "credentials. Anyone who can reach it can queue GPU jobs.",
            flush=True,
        )

    uvicorn.run(
        app,
        host=_env("COMFYUI_MCP_HOST", "0.0.0.0"),
        port=int(_env("COMFYUI_MCP_PORT", "8000")),
        log_level=_env("COMFYUI_MCP_LOG_LEVEL", "info").lower(),
    )


if __name__ == "__main__":
    main()
