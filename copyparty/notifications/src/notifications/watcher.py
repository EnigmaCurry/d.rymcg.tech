from __future__ import annotations
import asyncio
import json
import os
import re
import time
from dataclasses import dataclass
from typing import Iterable, List, Optional, Dict, Any

from watchfiles import awatch, Change


@dataclass(frozen=True)
class FileEvent:
    path: str
    change: str  # "added" | "modified" | "deleted"
    size: Optional[int]
    mtime: Optional[float]


def _event_to_name(ev: Change) -> str:
    return {Change.added: "added", Change.modified: "modified", Change.deleted: "deleted"}.get(ev, "modified")


def _stat_safe(p: str) -> tuple[Optional[int], Optional[float]]:
    try:
        st = os.stat(p)
        return st.st_size, st.st_mtime
    except FileNotFoundError:
        return None, None


class DirectoryWatcher:
    def __init__(
        self,
        paths: Iterable[str],
        debounce_seconds: float = 3.0,
        ignore_regex: Optional[str] = None,
        include_exts: Optional[List[str]] = None,
    ):
        self.paths = list(paths)
        self.debounce = debounce_seconds
        self.ignore_re = re.compile(ignore_regex) if ignore_regex else None
        self.include_exts = set(e.lower().lstrip(".") for e in (include_exts or []) if e)

    def _should_ignore(self, path: str) -> bool:
        name = os.path.basename(path)
        if self.ignore_re and self.ignore_re.search(name):
            return True
        if self.include_exts:
            ext = os.path.splitext(name)[1].lower().lstrip(".")
            if ext not in self.include_exts:
                return True
        return False

    async def events(self):
        # Listen on all dirs concurrently
        queues = [asyncio.Queue() for _ in self.paths]

        async def _watch_one(path: str, q: asyncio.Queue):
            async for changes in awatch(path, debounce=self.debounce, recursive=True, step=500):
                for ev, p in changes:
                    if self._should_ignore(p):
                        continue
                    size, mtime = _stat_safe(p) if ev != Change.deleted else (None, None)
                    await q.put(FileEvent(p, _event_to_name(ev), size, mtime))

        tasks = [asyncio.create_task(_watch_one(p, q)) for p, q in zip(self.paths, queues)]

        try:
            while True:
                # fan-in
                dones, _ = await asyncio.wait(
                    [asyncio.create_task(q.get()) for q in queues],
                    return_when=asyncio.FIRST_COMPLETED,
                )
                for d in dones:
                    yield d.result()
        finally:
            for t in tasks:
                t.cancel()
