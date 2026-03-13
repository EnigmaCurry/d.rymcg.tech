#!/usr/bin/env python3
# Auto-activate the project venv when invoked directly (outside the CLI/container)
import os as _os, sys as _sys
_venv = _os.path.join(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__))),
                      ".venv", "bin", "python3")
if _os.path.exists(_venv) and _os.path.abspath(_sys.executable) != _os.path.abspath(_venv):
    _os.execv(_venv, [_venv] + _sys.argv)
"""
request_controller.py - HTTP job queue controller for d.rymcg.tech

Runs a FastAPI server that accepts deployment jobs via REST API.
Jobs are queued and executed sequentially per-context.
When a job fails, all remaining pending jobs are cancelled.

Usage:
    # Start the server (inside drt container):
    d.rymcg.tech request-controller mycontext

    # Generate auth token:
    d.rymcg.tech request-controller-token --subject matrix-bot
"""

from __future__ import annotations

import argparse
import asyncio
import os
import secrets
import ssl
import subprocess
import sys
import tempfile
import uuid
from collections import OrderedDict
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Literal

import jwt
import uvicorn
from fastapi import Depends, FastAPI, HTTPException, Query, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

# Import models from request.py
sys.path.insert(0, str(Path(__file__).parent))
from request import (
    CommandResult,
    RequestAction,
    RequestItem,
    execute_request,
    get_cli_path,
    get_root_dir,
)

# ---------------------------------------------------------------------------
# Job model
# ---------------------------------------------------------------------------

class Job(BaseModel):
    id: str
    status: Literal["pending", "running", "completed", "failed", "cancelled"]
    created_at: datetime
    started_at: datetime | None = None
    finished_at: datetime | None = None
    requests: list[RequestItem]
    results: list[CommandResult] | None = None
    error: str | None = None


# ---------------------------------------------------------------------------
# TLS helpers
# ---------------------------------------------------------------------------

DATA_DIR = Path("/data")


def _get_age_public_key() -> str:
    """Extract the AGE public key from the SOPS_AGE_KEY_FILE."""
    key_file = os.environ.get("SOPS_AGE_KEY_FILE", "")
    if not key_file or not Path(key_file).exists():
        raise RuntimeError("SOPS_AGE_KEY_FILE not set or file missing")
    # If the key file is passphrase-encrypted, it was already decrypted
    # by entrypoint.sh into SOPS_AGE_KEY_FILE. Read the public key line.
    text = Path(key_file).read_text()
    for line in text.splitlines():
        if line.startswith("# public key:"):
            return line.split(":", 1)[1].strip()
    raise RuntimeError("Could not extract public key from AGE key file")


def _age_encrypt(data: bytes, pubkey: str) -> bytes:
    """Encrypt data with AGE public key."""
    proc = subprocess.run(
        ["age", "-r", pubkey],
        input=data, capture_output=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"age encrypt failed: {proc.stderr.decode()}")
    return proc.stdout


def _age_decrypt(ciphertext: bytes) -> bytes:
    """Decrypt AGE ciphertext using SOPS_AGE_KEY_FILE."""
    key_file = os.environ.get("SOPS_AGE_KEY_FILE", "")
    proc = subprocess.run(
        ["age", "-d", "-i", key_file],
        input=ciphertext, capture_output=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"age decrypt failed: {proc.stderr.decode()}")
    return proc.stdout


def _cert_fingerprint(cert_path: Path) -> str:
    """Get SHA-256 fingerprint of a TLS certificate."""
    proc = subprocess.run(
        ["openssl", "x509", "-in", str(cert_path), "-noout", "-fingerprint", "-sha256"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        return "unknown"
    # Output: SHA256 Fingerprint=AA:BB:CC:...
    return proc.stdout.strip().split("=", 1)[-1]


def setup_tls() -> tuple[Path, Path]:
    """Set up TLS cert/key. Returns (cert_path, key_tmpfile_path).

    The plaintext key is written to a temp file that should be cleaned up
    on shutdown.
    """
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    cert_path = DATA_DIR / "tls-cert.pem"
    enc_key_path = DATA_DIR / "tls-key.pem.age"

    if enc_key_path.exists() and cert_path.exists():
        # Decrypt existing key
        key_pem = _age_decrypt(enc_key_path.read_bytes())
    else:
        # Generate self-signed cert + key
        key_tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".pem")
        key_tmp.close()
        try:
            subprocess.run(
                [
                    "openssl", "req", "-x509", "-newkey", "ec",
                    "-pkeyopt", "ec_paramgen_curve:prime256v1",
                    "-keyout", key_tmp.name, "-out", str(cert_path),
                    "-days", "3650", "-nodes",
                    "-subj", "/CN=drt-request-controller",
                ],
                capture_output=True, check=True,
            )
            key_pem = Path(key_tmp.name).read_bytes()
        finally:
            os.unlink(key_tmp.name)

        # Encrypt key with AGE and save
        pubkey = _get_age_public_key()
        encrypted_key = _age_encrypt(key_pem, pubkey)
        enc_key_path.write_bytes(encrypted_key)
        cert_path.chmod(0o644)
        print(f"Generated new TLS certificate: {cert_path}", file=sys.stderr)

    # Write decrypted key to temp file for uvicorn
    key_tmpfile = tempfile.NamedTemporaryFile(delete=False, suffix=".pem")
    key_tmpfile.write(key_pem)
    key_tmpfile.close()
    os.chmod(key_tmpfile.name, 0o600)

    fingerprint = _cert_fingerprint(cert_path)
    print(f"TLS certificate fingerprint (SHA-256): {fingerprint}", file=sys.stderr)

    return cert_path, Path(key_tmpfile.name)


# ---------------------------------------------------------------------------
# JWT helpers
# ---------------------------------------------------------------------------

JWT_ALGORITHM = "HS256"


def load_or_create_master_key() -> bytes:
    """Load JWT master key from /data, or create one."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    enc_path = DATA_DIR / "jwt-master.key.age"

    if enc_path.exists():
        try:
            return _age_decrypt(enc_path.read_bytes())
        except RuntimeError:
            print("WARNING: Could not decrypt JWT master key (AGE key changed?). Generating new one.", file=sys.stderr)

    # Generate new master key
    master_key = secrets.token_bytes(32)
    pubkey = _get_age_public_key()
    encrypted = _age_encrypt(master_key, pubkey)
    enc_path.write_bytes(encrypted)
    print("Generated new JWT master key.", file=sys.stderr)
    return master_key


def generate_token(master_key: bytes, subject: str, expires_days: int = 30) -> str:
    """Generate a signed JWT token."""
    now = datetime.now(timezone.utc)
    payload = {
        "sub": subject,
        "iat": now,
        "exp": now + timedelta(days=expires_days),
    }
    return jwt.encode(payload, master_key, algorithm=JWT_ALGORITHM)


def verify_token(token: str, master_key: bytes) -> dict:
    """Verify and decode a JWT token."""
    return jwt.decode(token, master_key, algorithms=[JWT_ALGORITHM])


# ---------------------------------------------------------------------------
# Application state
# ---------------------------------------------------------------------------

class AppState:
    def __init__(self, context: str, master_key: bytes):
        self.context = context
        self.master_key = master_key
        self.jobs: OrderedDict[str, Job] = OrderedDict()
        self.job_queue: asyncio.Queue[str] = asyncio.Queue()
        self.job_events: dict[str, asyncio.Event] = {}
        self.cli_path = get_cli_path()
        self.root_dir = get_root_dir()


app_state: AppState | None = None


# ---------------------------------------------------------------------------
# Worker
# ---------------------------------------------------------------------------

async def worker_loop(state: AppState):
    """Process jobs from the queue one at a time."""
    loop = asyncio.get_event_loop()
    while True:
        job_id = await state.job_queue.get()
        job = state.jobs.get(job_id)
        if job is None or job.status != "pending":
            state.job_queue.task_done()
            continue

        job.status = "running"
        job.started_at = datetime.now(timezone.utc)
        all_results: list[CommandResult] = []
        failed = False

        for req in job.requests:
            if failed:
                break
            try:
                results = await loop.run_in_executor(
                    None,
                    lambda r=req: execute_request(
                        r, state.cli_path, state.root_dir,
                        dry_run=False, timeout=r.timeout or 300,
                    ),
                )
                all_results.extend(results)
                if any(not r.success for r in results):
                    failed = True
            except Exception as e:
                all_results.append(
                    CommandResult(
                        project=req.project,
                        action=req.action.value,
                        context=req.context,
                        instance=req.instance,
                        success=False,
                        exit_code=1,
                        command=[],
                        skipped=False,
                        error=str(e),
                    )
                )
                failed = True

        job.results = all_results
        job.finished_at = datetime.now(timezone.utc)

        if failed:
            job.status = "failed"
            job.error = "One or more requests failed"
            cancel_all_pending(state, f"Cancelled due to failure of job {job_id}")
        else:
            job.status = "completed"

        # Signal waiters
        event = state.job_events.get(job_id)
        if event:
            event.set()

        state.job_queue.task_done()


def cancel_all_pending(state: AppState, reason: str):
    """Cancel all pending jobs."""
    for job in state.jobs.values():
        if job.status == "pending":
            job.status = "cancelled"
            job.error = reason
            job.finished_at = datetime.now(timezone.utc)
            event = state.job_events.get(job.id)
            if event:
                event.set()


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(worker_loop(app_state))
    yield
    task.cancel()
    # Clean up TLS key temp file
    if hasattr(app, "_tls_key_tmpfile"):
        try:
            os.unlink(app._tls_key_tmpfile)
        except OSError:
            pass


app = FastAPI(title="d.rymcg.tech Request Controller", lifespan=lifespan)
security = HTTPBearer()


def get_state() -> AppState:
    return app_state


def verify_auth(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    state: AppState = Depends(get_state),
) -> dict:
    try:
        return verify_token(credentials.credentials, state.master_key)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


# --- Endpoints ---

@app.get("/health")
def health(state: AppState = Depends(get_state)):
    return {
        "status": "ok",
        "context": state.context,
        "queue_size": state.job_queue.qsize(),
    }


class JobResponse(BaseModel):
    id: str
    status: str


@app.post("/jobs", response_model=JobResponse)
def create_job(
    requests_body: list[dict],
    state: AppState = Depends(get_state),
    _auth: dict = Depends(verify_auth),
):
    # Parse and validate request items
    items: list[RequestItem] = []
    for i, req_dict in enumerate(requests_body):
        try:
            item = RequestItem(**req_dict)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Request {i}: {e}")
        if item.context != state.context:
            raise HTTPException(
                status_code=400,
                detail=f"Request {i}: context '{item.context}' does not match controller context '{state.context}'",
            )
        items.append(item)

    job_id = str(uuid.uuid4())
    job = Job(
        id=job_id,
        status="pending",
        created_at=datetime.now(timezone.utc),
        requests=items,
    )
    state.jobs[job_id] = job
    state.job_events[job_id] = asyncio.Event()
    state.job_queue.put_nowait(job_id)

    return JobResponse(id=job_id, status=job.status)


@app.get("/jobs")
def list_jobs(
    status: str | None = Query(default=None),
    state: AppState = Depends(get_state),
    _auth: dict = Depends(verify_auth),
):
    jobs = list(state.jobs.values())
    if status:
        jobs = [j for j in jobs if j.status == status]
    return [
        {
            "id": j.id,
            "status": j.status,
            "created_at": j.created_at.isoformat(),
            "started_at": j.started_at.isoformat() if j.started_at else None,
            "finished_at": j.finished_at.isoformat() if j.finished_at else None,
            "request_count": len(j.requests),
            "error": j.error,
        }
        for j in jobs
    ]


@app.get("/jobs/{job_id}")
def get_job(
    job_id: str,
    state: AppState = Depends(get_state),
    _auth: dict = Depends(verify_auth),
):
    job = state.jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job.model_dump(mode="json")


@app.delete("/jobs/{job_id}")
def cancel_job(
    job_id: str,
    state: AppState = Depends(get_state),
    _auth: dict = Depends(verify_auth),
):
    job = state.jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    if job.status != "pending":
        raise HTTPException(status_code=409, detail=f"Job is {job.status}, not pending")
    job.status = "cancelled"
    job.error = "Cancelled by user"
    job.finished_at = datetime.now(timezone.utc)
    event = state.job_events.get(job_id)
    if event:
        event.set()
    return {"id": job_id, "status": "cancelled"}


@app.post("/jobs/clear")
def clear_jobs(
    state: AppState = Depends(get_state),
    _auth: dict = Depends(verify_auth),
):
    to_remove = [
        jid for jid, j in state.jobs.items()
        if j.status in ("cancelled", "failed")
    ]
    for jid in to_remove:
        del state.jobs[jid]
        state.job_events.pop(jid, None)
    return {"removed": len(to_remove)}


@app.get("/jobs/{job_id}/wait")
async def wait_for_job(
    job_id: str,
    timeout: int = Query(default=300, le=600),
    state: AppState = Depends(get_state),
    _auth: dict = Depends(verify_auth),
):
    job = state.jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if job.status in ("completed", "failed", "cancelled"):
        return job.model_dump(mode="json")

    event = state.job_events.get(job_id)
    if not event:
        event = asyncio.Event()
        state.job_events[job_id] = event

    try:
        await asyncio.wait_for(event.wait(), timeout=timeout)
    except asyncio.TimeoutError:
        raise HTTPException(status_code=408, detail="Timeout waiting for job completion")

    job = state.jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job.model_dump(mode="json")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="d.rymcg.tech request controller - HTTP job queue"
    )
    parser.add_argument(
        "--generate-token",
        action="store_true",
        help="Generate a JWT auth token and exit",
    )
    parser.add_argument(
        "--subject",
        type=str,
        help="Token subject/label (required with --generate-token)",
    )
    parser.add_argument(
        "--expires-days",
        type=int,
        default=30,
        help="Token expiration in days (default: 30)",
    )
    parser.add_argument(
        "--host",
        default="::",
        help="Bind address (default: :: dual-stack)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8084,
        help="Listen port (default: 8084)",
    )

    args = parser.parse_args()

    if args.generate_token:
        if not DATA_DIR.exists():
            print(f"Error: {DATA_DIR} does not exist. This command must run inside the drt container.", file=sys.stderr)
            print(f"  Usage: drt CONTEXT request-controller-token --subject NAME", file=sys.stderr)
            sys.exit(1)
        master_key = load_or_create_master_key()
        if not args.subject:
            print("Error: --subject is required with --generate-token", file=sys.stderr)
            sys.exit(1)
        token = generate_token(master_key, args.subject, args.expires_days)
        # Decode and print claims to stderr
        claims = jwt.decode(token, master_key, algorithms=[JWT_ALGORITHM])
        for key, value in claims.items():
            if key in ("iat", "exp"):
                value = datetime.fromtimestamp(value, tz=timezone.utc).isoformat()
            print(f"##  {key}: {value}", file=sys.stderr)
        print("##", file=sys.stderr)
        print("##  Usage:", file=sys.stderr)
        print(f"##  curl -sk https://localhost:8084/health", file=sys.stderr)
        print(f"##  curl -sk https://localhost:8084/jobs -H 'Authorization: Bearer {token}'", file=sys.stderr)
        print("##", file=sys.stderr)
        print(token)
        return

    context = os.environ.get("DRT_CONTEXT", "")
    if not context:
        print("Error: DRT_CONTEXT environment variable not set.", file=sys.stderr)
        print("  This command must run inside the drt container.", file=sys.stderr)
        print("  Usage: drt CONTEXT request-controller", file=sys.stderr)
        sys.exit(1)

    if not DATA_DIR.exists():
        print(f"Error: {DATA_DIR} does not exist. This command must run inside the drt container.", file=sys.stderr)
        print(f"  Usage: drt {context} request-controller", file=sys.stderr)
        sys.exit(1)

    global app_state
    master_key = load_or_create_master_key()
    app_state = AppState(context, master_key)

    # Set up TLS
    cert_path, key_tmpfile = setup_tls()
    app._tls_key_tmpfile = str(key_tmpfile)

    print(f"Starting request controller for context '{context}'", file=sys.stderr)
    print(f"Listening on https://{args.host}:{args.port}", file=sys.stderr)

    uvicorn.run(
        app,
        host=args.host,
        port=args.port,
        ssl_keyfile=str(key_tmpfile),
        ssl_certfile=str(cert_path),
        log_level="info",
    )


if __name__ == "__main__":
    main()
