from fastapi.responses import StreamingResponse
import httpx
from fastapi import FastAPI, Request
import logging
import re
from urllib.parse import urlparse

log = logging.getLogger(__name__)


def rewrite_relative_links(content: bytes, base_path: str) -> bytes:
    decoded_content = content.decode("utf-8")
    updated_content = re.sub(
        r'href="(/[^"]+)"', f'href="{base_path}\\1"', decoded_content
    )
    updated_content = re.sub(
        r'src="(/[^"]+)"', f'src="{base_path}\\1"', updated_content
    )
    return updated_content.encode("utf-8")


async def proxy_request(request: Request, target_url: str, base_path: str = "/"):
    headers = {key: value for key, value in request.headers.items()}

    # Remove the base path prefix from the incoming request URL if base_path is not "/" and the path starts with base_path
    if base_path != "/" and request.url.path.startswith(base_path):
        stripped_path = request.url.path[len(base_path) :]
    else:
        stripped_path = request.url.path

    # Append the stripped path to the target URL, ignoring the base path completely
    parsed_target_url = urlparse(target_url)
    full_target_url = parsed_target_url._replace(path=stripped_path).geturl()
    log.debug(f"Proxying URL: {full_target_url}")
    async with httpx.AsyncClient(timeout=300) as client:
        # Forward the request based on the HTTP method
        response = await client.request(
            method=request.method,
            url=full_target_url,
            headers=headers,
            params=request.query_params,
            content=await request.body() if request.method in ["POST", "PUT"] else None,
        )

        # Rewrite links if content-type is HTML and base_path is not "/"
        if base_path != "/" and response.headers.get("content-type", "").startswith(
            "text/html"
        ):
            content = rewrite_relative_links(await response.aread(), base_path)
        else:
            content = await response.aread()

    # Return the response, streaming back the content
    return StreamingResponse(
        content=iter([content]),
        status_code=response.status_code,
        headers=dict(response.headers),
    )
