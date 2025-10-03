from __future__ import annotations
import os
from pydantic import BaseModel, Field
from typing import List, Optional


def _split_env(name: str, default: str | None = None) -> List[str]:
    v = os.getenv(name, default or "")
    return [x.strip() for x in v.split(",") if x.strip()]


class WebhookConfig(BaseModel):
    url: Optional[str] = Field(default=None)
    username: Optional[str] = None
    password: Optional[str] = None
    token: Optional[str] = None  # Bearer token


class NtfyConfig(BaseModel):
    url: Optional[str] = Field(default=None)  # e.g. https://ntfy.example.com/mytopic
    username: Optional[str] = None
    password: Optional[str] = None
    token: Optional[str] = None  # Bearer token


class AppConfig(BaseModel):
    # "webhook", "ntfy", or "webhook,ntfy"
    methods: List[str] = Field(default_factory=lambda: _split_env("COPYPARTY_NOTIFICATIONS_METHOD", "webhook"))
    # One or more paths (container paths), e.g. "/data,/more"
    monitor_paths: List[str] = Field(default_factory=lambda: _split_env("COPYPARTY_NOTIFICATIONS_MONITOR_VOLUMES", "/data"))
    debounce_seconds: float = float(os.getenv("COPYPARTY_NOTIFICATIONS_MONITOR_DEBOUNCE_SECONDS", "3"))

    # Ignore files ending with typical temp/partial suffixes
    ignore_regex: str = os.getenv(
        "COPYPARTY_NOTIFICATIONS_IGNORE_REGEX",
        r"(\.part|\.partial|\.tmp|\.uploading|\.incomplete)$",
    )
    # Only notify for these extensions (empty = all)
    include_exts: List[str] = Field(default_factory=lambda: _split_env("COPYPARTY_NOTIFICATIONS_INCLUDE_EXTS", ""))

    # Payload knobs
    instance: Optional[str] = os.getenv("INSTANCE")  # optional instance name to include in payloads

    webhook: WebhookConfig = Field(default_factory=lambda: WebhookConfig(
        url=os.getenv("COPYPARTY_NOTIFICATIONS_WEBHOOK_URL"),
        username=os.getenv("COPYPARTY_NOTIFICATIONS_WEBHOOK_USERNAME"),
        password=os.getenv("COPYPARTY_NOTIFICATIONS_WEBHOOK_PASSWORD"),
        token=os.getenv("COPYPARTY_NOTIFICATIONS_WEBHOOK_TOKEN"),
    ))
    ntfy: NtfyConfig = Field(default_factory=lambda: NtfyConfig(
        url=os.getenv("COPYPARTY_NOTIFICATIONS_NTFY_URL"),
        username=os.getenv("COPYPARTY_NOTIFICATIONS_NTFY_USERNAME"),
        password=os.getenv("COPYPARTY_NOTIFICATIONS_NTFY_PASSWORD"),
        token=os.getenv("COPYPARTY_NOTIFICATIONS_NTFY_TOKEN"),
    ))
