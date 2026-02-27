"""Shared library for image catalog, build, archive, and restore scripts."""

import hashlib
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent


def build_tag() -> str:
    """Generate a date-stamped tag for locally built images."""
    return f"d-rymcg-tech-{date.today().strftime('%Y%m%d')}"


def get_docker_context() -> str:
    """Get the name of the active Docker context."""
    result = subprocess.run(
        ["docker", "context", "ls", "--format", "{{.Current}} {{.Name}}"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print("ERROR: Failed to list Docker contexts", file=sys.stderr)
        sys.exit(2)
    for line in result.stdout.splitlines():
        if line.startswith("true "):
            return line.split(" ", 1)[1].strip()
    print("ERROR: No active Docker context found", file=sys.stderr)
    sys.exit(2)


def get_ssh_host() -> str:
    """Get the SSH host from the active Docker context."""
    result = subprocess.run(
        ["docker", "context", "inspect", "--format", "{{.Endpoints.docker.Host}}"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print("ERROR: Failed to inspect Docker context", file=sys.stderr)
        sys.exit(2)
    host = result.stdout.strip().replace("ssh://", "")
    if not host:
        print("ERROR: Docker context does not use SSH", file=sys.stderr)
        sys.exit(2)
    return host


def get_catalog(project_filter: str | None = None) -> list[dict]:
    """Run image-catalog --json and return parsed entries."""
    script = ROOT_DIR / "_scripts" / "image-catalog"
    result = subprocess.run(
        [str(script), "--json"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"ERROR: image-catalog failed: {result.stderr}", file=sys.stderr)
        sys.exit(2)
    entries = json.loads(result.stdout)
    if project_filter:
        entries = [e for e in entries if e["project"] == project_filter]
    return entries


def find_env_file(project_dir: Path, context: str) -> Path:
    """Find the env file for a project: context-specific or .env-dist fallback."""
    context_env = project_dir / f".env_{context}_default"
    if context_env.exists():
        return context_env
    env_dist = project_dir / ".env-dist"
    if env_dist.exists():
        return env_dist
    return project_dir / ".env-dist"


def resolve_compose_images(project_dir: Path, env_file: Path) -> dict[str, str]:
    """Run docker compose config to get resolved image names per service."""
    cmd = [
        "docker", "compose",
        "-f", str(project_dir / "docker-compose.yaml"),
        "--env-file", str(env_file),
        "--profile", "*",
        "config", "--format", "json",
    ]
    context = env_file.stem.replace(".env_", "").rsplit("_", 1)[0] if "_" in env_file.stem else ""
    if context:
        override = project_dir / f"docker-compose.override_{context}_default.yaml"
        if override.exists():
            cmd = [
                "docker", "compose",
                "-f", str(project_dir / "docker-compose.yaml"),
                "-f", str(override),
                "--env-file", str(env_file),
                "--profile", "*",
                "config", "--format", "json",
            ]

    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(project_dir))
    if result.returncode != 0:
        return {}

    try:
        config = json.loads(result.stdout)
    except json.JSONDecodeError:
        return {}

    project_name = config.get("name", "")
    images = {}
    for svc_name, svc_config in config.get("services", {}).items():
        image = svc_config.get("image")
        if not image and svc_config.get("build"):
            image = f"{project_name}-{svc_name}:{build_tag()}" if project_name else None
        if image:
            images[svc_name] = image
    return images


def sanitize_filename(image: str) -> str:
    """Convert an image reference to a safe filename."""
    name = image.replace("/", "_").replace(":", "_").replace("@", "_")
    name = re.sub(r"[^\w\-.]", "_", name)
    return name + ".tar.gz"


def sha256sum(path: Path) -> str:
    """Compute SHA256 hash of a file."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def get_docker_image_id(image: str) -> str | None:
    """Get the Docker image ID (content digest) for an image."""
    result = subprocess.run(
        ["docker", "image", "inspect", image, "--format", "{{.Id}}"],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        return result.stdout.strip()
    return None


def get_remote_arch(ssh_host: str) -> str:
    """Get the architecture of the remote Docker host."""
    result = subprocess.run(
        ["ssh", ssh_host, "uname -m"],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        return result.stdout.strip()
    return "x86_64"


def run_cmd(cmd: list[str], verbose: bool = False, **kwargs) -> subprocess.CompletedProcess:
    """Run a command, optionally showing output."""
    if verbose:
        return subprocess.run(cmd, **kwargs)
    return subprocess.run(cmd, capture_output=True, text=True, **kwargs)


def pull_image(image: str, verbose: bool = False) -> bool:
    """Pull an image on the remote Docker host."""
    result = run_cmd(["docker", "pull", image], verbose=verbose)
    return result.returncode == 0


BUILD_SOURCES = ("build-local", "build-remote", "build-only")


def run_build_hook_pre(project_dir: Path, verbose: bool = False) -> bool:
    """Run the Makefile build-hook-pre target if it exists."""
    check = subprocess.run(
        ["make", "--no-print-directory", "-n", "build-hook-pre"],
        capture_output=True, text=True, cwd=str(project_dir),
    )
    if check.returncode != 0:
        return True  # no hook, that's fine
    if verbose:
        print(f"    Running build-hook-pre...", file=sys.stderr)
    result = run_cmd(
        ["make", "--no-print-directory", "build-hook-pre"],
        verbose=verbose, cwd=str(project_dir),
    )
    if result.returncode != 0:
        print(f"    WARNING: build-hook-pre failed", file=sys.stderr)
        return False
    return True


def build_service(project_dir: Path, env_file: Path, service: str, verbose: bool = False, pull: bool = False, no_cache: bool = False) -> bool:
    """Build a service on the remote Docker host."""
    run_build_hook_pre(project_dir, verbose=verbose)
    cmd = [
        "docker", "compose",
        "-f", str(project_dir / "docker-compose.yaml"),
        "--env-file", str(env_file),
        "--profile", "*",
        "build",
    ]
    if pull:
        cmd.append("--pull")
    if no_cache:
        cmd.append("--no-cache")
    cmd.append(service)
    result = run_cmd(cmd, verbose=verbose, cwd=str(project_dir))
    return result.returncode == 0


def retag_image(old_name: str, new_name: str, verbose: bool = False) -> bool:
    """Create a new tag for an existing image."""
    result = run_cmd(["docker", "tag", old_name, new_name], verbose=verbose)
    return result.returncode == 0


def collect_images(
    catalog: list[dict],
    compose_images: dict[str, str],
    project_name: str,
    pull_only: bool = False,
) -> tuple[dict[str, dict], list[str]]:
    """Collect unique images to process for a project.

    Returns (images_dict, skipped_list) where images_dict maps
    image -> {source, services, build_service}.
    """
    images: dict[str, dict] = {}
    skipped: list[str] = []

    for entry in catalog:
        source = entry["source"]
        service = entry["service"]
        image_resolved = entry.get("image_resolved")

        if pull_only and source in BUILD_SOURCES:
            skipped.append(f"{project_name}/{service} (build, skipped with --pull-only)")
            continue

        image = compose_images.get(service) or image_resolved
        if image and image.startswith("(build-arg"):
            image = image.split(") ", 1)[-1] if ") " in image else None

        if not image and source in BUILD_SOURCES:
            image = f"{project_name}-{service}:{build_tag()}"

        if not image:
            skipped.append(f"{project_name}/{service} (no resolved image)")
            continue

        if image not in images:
            images[image] = {
                "source": source,
                "services": [],
                "build_service": service if source in BUILD_SOURCES else None,
            }
        images[image]["services"].append(service)
        if source in BUILD_SOURCES:
            images[image]["source"] = source
            images[image]["build_service"] = service

    return images, skipped
