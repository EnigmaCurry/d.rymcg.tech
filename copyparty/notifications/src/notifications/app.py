# notifications/app.py
from __future__ import annotations

import os
import time
import json
import hashlib
import threading
import signal
from pathlib import Path
from queue import Queue, Empty
from typing import List, Optional, Dict, Any

import httpx
from pydantic import BaseModel, Field, AnyHttpUrl
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileCreatedEvent, FileModifiedEvent, FileMovedEvent

# -----------------------
# Configuration
# -----------------------

class Method(str):
    WEBHOOK = "webhook"
    NTFY = "ntfy"

class Settings(BaseModel):
    # Which delivery method to use: "webhook" or "ntfy"
    method: str = Field(default_factory=lambda: os.getenv("COPYPARTY_NOTIFICATIONS_METHOD", "").strip().lower())

    # Webhook config
    webhook_url: Optional[AnyHttpUrl] = Field(default_factory=lambda: os.getenv("COPYPARTY_NOTIFICATIONS_WEBHOOK_URL") or None)
    webhook_username: Optional[str] = Field(default_factory=lambda: os.getenv("COPYPARTY_NOTIFICATIONS_WEBHOOK_USERNAME") or None)
    webhook_password: Optional[str] = Field(default_factory=lambda: os.getenv("COPYPARTY_NOTIFICATIONS_WEBHOOK_PASSWORD") or None)
    webhook_token: Optional[str]    = Field(default_factory=lambda: os.getenv("COPYPARTY_NOTIFICATIONS_WEBHOOK_TOKEN") or None)

    # ntfy config (expects the full publish URL, typically .../topic)
    ntfy_url: Optional[AnyHttpUrl] = Field(default_factory=lambda: os.getenv("COPYPARTY_NOTIFICATIONS_NTFY_URL") or None)
    ntfy_username: Optional[str] = Field(default_factory=lambda: os.getenv("COPYPARTY_NOTIFICATIONS_NTFY_USERNAME") or None)
    ntfy_password: Optional[str] = Field(default_factory=lambda: os.getenv("COPYPARTY_NOTIFICATIONS_NTFY_PASSWORD") or None)
    ntfy_token: Optional[str]    = Field(default_factory=lambda: os.getenv("COPYPARTY_NOTIFICATIONS_NTFY_TOKEN") or None)

    # Comma-separated list of dirs to watch (absolute paths inside the container)
    monitor_volumes_raw: str = Field(default_factory=lambda: os.getenv("COPYPARTY_NOTIFICATIONS_MONITOR_VOLUMES", ""))

    # Debounce seconds per file path
    debounce_seconds: float = Field(default_factory=lambda: float(os.getenv("COPYPARTY_NOTIFICATIONS_MONITOR_DEBOUNCE_SECONDS", "1.0")))

    # Optional: compute a quick hash for small files to help dedupe (disabled by default)
    quick_hash_max_bytes: int = Field(default_factory=lambda: int(os.getenv("COPYPARTY_NOTIFICATIONS_QUICK_HASH_MAX_BYTES", "0")))

    # Optional: small health HTTP server (set a port to enable)
    health_port: Optional[int] = Field(default_factory=lambda: (int(os.getenv("COPYPARTY_NOTIFICATIONS_HEALTH_PORT", "0")) or None))

    def monitor_paths(self) -> List[Path]:
        raw = [p.strip() for p in self.monitor_volumes_raw.split(",") if p.strip()]
        return [Path(p) for p in raw]

    def validate_method(self) -> None:
        if self.method not in {Method.WEBHOOK, Method.NTFY}:
            raise ValueError("COPYPARTY_NOTIFICATIONS_METHOD must be 'webhook' or 'ntfy'")
        if self.method == Method.WEBHOOK and not self.webhook_url:
            raise ValueError("COPYPARTY_NOTIFICATIONS_WEBHOOK_URL is required for webhook method")
        if self.method == Method.NTFY and not self.ntfy_url:
            raise ValueError("COPYPARTY_NOTIFICATIONS_NTFY_URL is required for ntfy method")
        if not self.monitor_paths():
            raise ValueError("COPYPARTY_NOTIFICATIONS_MONITOR_VOLUMES must list at least one directory")


# -----------------------
# Event model
# -----------------------

class FileEvent(BaseModel):
    event: str           # 'created' | 'modified' | 'moved'
    path: str            # absolute path inside container
    dest_path: Optional[str] = None  # for moved
    size: Optional[int]  = None
    mtime: Optional[float] = None
    quick_hash: Optional[str] = None # optional short hash to coalesce duplicates
    source: str = "copyparty"

# -----------------------
# Delivery
# -----------------------

class Notifier:
    def __init__(self, settings: Settings) -> None:
        self.s = settings
        self.client = httpx.Client(timeout=10)

    def _auth_headers(self, username: Optional[str], password: Optional[str], bearer: Optional[str]) -> Dict[str, str]:
        headers: Dict[str, str] = {"User-Agent": "copyparty-notifications/0.1"}
        if bearer:
            headers["Authorization"] = f"Bearer {bearer}"
        elif username and password:
            # For httpx, auth can also be passed as (username, password) but we’ll keep it simple with Basic
            import base64
            token = base64.b64encode(f"{username}:{password}".encode()).decode()
            headers["Authorization"] = f"Basic {token}"
        return headers

    @retry(
        reraise=True,
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=0.5, min=0.5, max=8),
        retry=retry_if_exception_type(httpx.HTTPError),
    )
    def send(self, fe: FileEvent) -> None:
        if self.s.method == Method.WEBHOOK:
            self._send_webhook(fe)
        else:
            self._send_ntfy(fe)

    def _send_webhook(self, fe: FileEvent) -> None:
        headers = self._auth_headers(self.s.webhook_username, self.s.webhook_password, self.s.webhook_token)
        headers["Content-Type"] = "application/json"
        payload = fe.model_dump()
        resp = self.client.post(str(self.s.webhook_url), headers=headers, json=payload)
        resp.raise_for_status()

    def _send_ntfy(self, fe: FileEvent) -> None:
        # ntfy accepts a POST to the topic URL; body is the message.
        # We’ll include a concise text and send metadata as X- headers.
        headers = self._auth_headers(self.s.ntfy_username, self.s.ntfy_password, self.s.ntfy_token)
        headers.update({
            "Title": f"{fe.source}: {fe.event}",
            "Content-Type": "text/plain",
            # You could set Priority: 1..5 or Tags: paperclip, etc.
        })
        text = f"{fe.event}: {fe.path}"
        if fe.dest_path:
            text += f" -> {fe.dest_path}"
        # Include small JSON context as an additional header for consumers that want it
        headers["X-File-Meta"] = json.dumps({k: v for k, v in fe.model_dump().items() if k not in ("event","path","dest_path")})
        resp = self.client.post(str(self.s.ntfy_url), headers=headers, content=text.encode())
        resp.raise_for_status()


# -----------------------
# Watcher (inotify via watchdog)
# -----------------------

class DebouncingHandler(FileSystemEventHandler):
    def __init__(self, settings: Settings, outq: Queue) -> None:
        self.s = settings
        self.outq = outq
        self.last_emit: Dict[str, float] = {}
        self.hash_cache: Dict[str, str] = {}

    def _maybe_hash(self, path: Path) -> Optional[str]:
        maxb = self.s.quick_hash_max_bytes
        if maxb <= 0:
            return None
        try:
            if path.is_file():
                with path.open("rb") as f:
                    chunk = f.read(maxb)
                return hashlib.sha256(chunk).hexdigest()
        except Exception:
            return None
        return None

    def _stat_meta(self, p: Path) -> Dict[str, Any]:
        try:
            st = p.stat()
            return {"size": st.st_size, "mtime": st.st_mtime}
        except FileNotFoundError:
            return {"size": None, "mtime": None}

    def _emit(self, fe: FileEvent) -> None:
        key = fe.dest_path or fe.path
        now = time.time()
        last = self.last_emit.get(key, 0.0)
        if (now - last) < self.s.debounce_seconds:
            return
        self.last_emit[key] = now
        self.outq.put(fe)

    # Created
    def on_created(self, event):
        if isinstance(event, FileCreatedEvent) and not event.is_directory:
            p = Path(event.src_path)
            meta = self._stat_meta(p)
            fe = FileEvent(
                event="created",
                path=str(p),
                size=meta["size"],
                mtime=meta["mtime"],
                quick_hash=self._maybe_hash(p),
            )
            self._emit(fe)

    # Modified (often noisy; rely on debounce + optional hash)
    def on_modified(self, event):
        if isinstance(event, FileModifiedEvent) and not event.is_directory:
            p = Path(event.src_path)
            meta = self._stat_meta(p)
            fe = FileEvent(
                event="modified",
                path=str(p),
                size=meta["size"],
                mtime=meta["mtime"],
                quick_hash=self._maybe_hash(p),
            )
            self._emit(fe)

    # Moved/Renamed
    def on_moved(self, event):
        if isinstance(event, FileMovedEvent) and not event.is_directory:
            src = Path(event.src_path)
            dst = Path(event.dest_path)
            meta = self._stat_meta(dst if dst.exists() else src)
            fe = FileEvent(
                event="moved",
                path=str(src),
                dest_path=str(dst),
                size=meta["size"],
                mtime=meta["mtime"],
                quick_hash=self._maybe_hash(dst if dst.exists() else src),
            )
            self._emit(fe)


# -----------------------
# Health server (optional)
# -----------------------

def _start_health_server(port: int) -> threading.Thread:
    # Tiny uvicorn ASGI app inline to avoid extra files.
    import uvicorn
    from fastapi import FastAPI
    app = FastAPI()

    @app.get("/health")
    def health():
        return {"ok": True}

    th = threading.Thread(
        target=lambda: uvicorn.run(app, host="0.0.0.0", port=port, log_level="warning"),
        daemon=True,
    )
    th.start()
    return th


# -----------------------
# Main loop
# -----------------------

def run() -> None:
    settings = Settings()
    settings.validate_method()

    if settings.health_port:
        _start_health_server(settings.health_port)

    q: Queue[FileEvent] = Queue()
    handler = DebouncingHandler(settings, q)
    observer = Observer()

    for p in settings.monitor_paths():
        if not p.exists():
            raise FileNotFoundError(f"Monitor path does not exist: {p}")
        observer.schedule(handler, str(p), recursive=True)

    notifier = Notifier(settings)

    stop_flag = threading.Event()

    def _signal(*_):
        stop_flag.set()

    signal.signal(signal.SIGINT, _signal)
    signal.signal(signal.SIGTERM, _signal)

    observer.start()
    print(f"[notifications] watching: {', '.join(str(p) for p in settings.monitor_paths())}")
    print(f"[notifications] method: {settings.method}")

    try:
        while not stop_flag.is_set():
            try:
                fe: FileEvent = q.get(timeout=0.5)
            except Empty:
                continue
            try:
                notifier.send(fe)
                print(f"[notifications] sent: {fe.event} {fe.path}")
            except Exception as e:
                # Keep going; delivery is already retried with backoff
                print(f"[notifications] ERROR delivery: {e}", flush=True)
    finally:
        observer.stop()
        observer.join(timeout=5)
        print("[notifications] stopped.")
