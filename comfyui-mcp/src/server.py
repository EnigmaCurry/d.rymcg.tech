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
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Literal

import httpx
import uvicorn
from PIL import Image as PILImage
from mcp.server.fastmcp import Context, FastMCP, Image
from mcp.server.transport_security import TransportSecuritySettings
from starlette.datastructures import Headers
from starlette.responses import Response
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

    @property
    def sprite_path(self) -> Path:
        return DATA_DIR / f"{self.id}.png"

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
            f"{self.colors}c  seed={self.seed}  {age}s ago\n"
            f"    {self.prompt[:90]}"
        )
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
            job = Job(**data)
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
        for p in (job.sprite_path, job.view_path, job.meta_path):
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


def pixelate(raw_png: bytes, job: Job) -> tuple[bytes, bytes]:
    """Downscale onto a true pixel grid and quantize. Returns (sprite, view)."""
    src = PILImage.open(io.BytesIO(raw_png)).convert("RGB")
    resample = PILImage.NEAREST if job.resample == "nearest" else PILImage.BOX
    small = src.resize((job.size, job.size), resample)
    # Dithering scatters stray pixels and reads as noise at sprite scale.
    small = small.quantize(
        colors=job.colors,
        method=PILImage.Quantize.MEDIANCUT,
        dither=PILImage.Dither.NONE,
    ).convert("RGB")

    sprite_buf = io.BytesIO()
    small.save(sprite_buf, format="PNG")

    view = small.resize(
        (job.size * job.view_scale, job.size * job.view_scale), PILImage.NEAREST
    )
    view_buf = io.BytesIO()
    view.save(view_buf, format="PNG")
    return sprite_buf.getvalue(), view_buf.getvalue()


async def run_job(job: Job, ctx: Context | None = None) -> None:
    job.status = "running"
    job.save()
    try:
        async with httpx.AsyncClient(base_url=COMFYUI_URL, timeout=60.0) as client:
            resp = await client.post("/prompt", json={"prompt": build_workflow(job)})
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
