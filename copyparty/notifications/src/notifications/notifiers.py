from __future__ import annotations
import httpx
import base64
from typing import Dict, Any, Optional


def _basic_auth(username: Optional[str], password: Optional[str]) -> Optional[str]:
    if not username or not password:
        return None
    token = base64.b64encode(f"{username}:{password}".encode()).decode()
    return f"Basic {token}"


async def send_webhook(
    *,
    url: str,
    data: Dict[str, Any],
    username: Optional[str] = None,
    password: Optional[str] = None,
    token: Optional[str] = None,
    timeout=10.0,
) -> None:
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    elif (auth := _basic_auth(username, password)):
        headers["Authorization"] = auth

    async with httpx.AsyncClient(timeout=timeout) as client:
        r = await client.post(url, json=data, headers=headers)
        r.raise_for_status()


async def send_ntfy(
    *,
    url: str,
    title: str,
    message: str,
    tags: Optional[str] = None,
    username: Optional[str] = None,
    password: Optional[str] = None,
    token: Optional[str] = None,
    timeout=10.0,
) -> None:
    # Publish by POST to topic URL. Headers control title/tags.
    headers = {}
    if title:
        headers["Title"] = title
    if tags:
        headers["Tags"] = tags
    if token:
        headers["Authorization"] = f"Bearer {token}"
    elif username and password:
        # ntfy supports Basic auth too
        import base64
        headers["Authorization"] = "Basic " + base64.b64encode(f"{username}:{password}".encode()).decode()

    async with httpx.AsyncClient(timeout=timeout) as client:
        r = await client.post(url, content=message.encode("utf-8"), headers=headers)
        r.raise_for_status()
