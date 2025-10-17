from __future__ import annotations
import asyncio
import json
import logging
import os
from datetime import datetime, timezone
from pythonjsonlogger import jsonlogger

from .config import AppConfig
from .watcher import DirectoryWatcher, FileEvent
from . import notifiers


def _setup_logging():
    handler = logging.StreamHandler()
    fmt = jsonlogger.JsonFormatter("%(asctime)s %(levelname)s %(message)s")
    handler.setFormatter(fmt)
    log = logging.getLogger()
    log.setLevel(logging.INFO)
    log.addHandler(handler)
    return log


async def _handle_event(cfg: AppConfig, ev: FileEvent):
    # Common payload
    payload = {
        "type": "copyparty.upload",
        "instance": cfg.instance,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "file": {
            "path": ev.path,
            "change": ev.change,
            "size": ev.size,
            "mtime": ev.mtime,
        },
    }

    tasks = []
    if "webhook" in cfg.methods and cfg.webhook.url:
        tasks.append(
            notifiers.send_webhook(
                url=cfg.webhook.url,
                data=payload,
                username=cfg.webhook.username,
                password=cfg.webhook.password,
                token=cfg.webhook.token,
            )
        )
    if "ntfy" in cfg.methods and cfg.ntfy.url:
        title = f"{cfg.instance or 'copyparty'}: {ev.change}"
        msg = json.dumps(payload, ensure_ascii=False, indent=2)
        tasks.append(
            notifiers.send_ntfy(
                url=cfg.ntfy.url,
                title=title,
                message=msg,
                username=cfg.ntfy.username,
                password=cfg.ntfy.password,
                token=cfg.ntfy.token,
                tags="inbox,upload",
            )
        )

    if tasks:
        await asyncio.gather(*tasks, return_exceptions=False)


async def run():
    log = _setup_logging()
    cfg = AppConfig()
    if not cfg.monitor_paths:
        raise SystemExit("No monitor paths configured (COPYPARTY_NOTIFICATIONS_MONITOR_VOLUMES).")

    log.info(
        "starting",
        extra={
            "methods": cfg.methods,
            "paths": cfg.monitor_paths,
            "debounce": cfg.debounce_seconds,
            "ignore_regex": cfg.ignore_regex,
            "include_exts": cfg.include_exts,
            "instance": cfg.instance,
        },
    )

    watcher = DirectoryWatcher(
        cfg.monitor_paths,
        debounce_seconds=cfg.debounce_seconds,
        ignore_regex=cfg.ignore_regex,
        include_exts=cfg.include_exts,
    )

    try:
        async for ev in watcher.events():
            log.info("event", extra={"path": ev.path, "change": ev.change, "size": ev.size, "mtime": ev.mtime})
            # Only notify on added/modified; skip deletes by default
            if ev.change in ("added", "modified"):
                await _handle_event(cfg, ev)
    except asyncio.CancelledError:
        pass


def main():
    asyncio.run(run())
