#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["rich", "certifi"]
# ///
"""
mdview.py - lightweight terminal Markdown viewer (URL/file/stdin) using Rich.

Features:
- Fetch URLs with a portable TLS trust store (certifi).
- Render Markdown in a Rich pager.
- Auto-rewrite GitHub URLs to fetch raw Markdown:
  1) https://github.com/OWNER/REPO/blob/BRANCH/path.md
     -> https://github.com/OWNER/REPO/raw/BRANCH/path.md
  2) https://github.com/OWNER/REPO/tree/BRANCH[/subpath]#readme
     -> https://raw.githubusercontent.com/OWNER/REPO/refs/heads/BRANCH/[subpath/]README.md
"""

from __future__ import annotations

import argparse
import ssl
import sys
import urllib.request
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse, urlunparse

import certifi
from rich.console import Console
from rich.markdown import Markdown


def parse_headers(items: list[str]) -> dict[str, str]:
    headers: dict[str, str] = {}
    for item in items:
        if ":" not in item:
            raise ValueError(f"Bad header (expected 'Name: value'): {item!r}")
        name, value = item.split(":", 1)
        headers[name.strip()] = value.lstrip()
    return headers


def rewrite_github_url(url: str) -> str:
    """
    Convert GitHub HTML URLs into raw markdown fetch URLs.
    """
    p = urlparse(url)
    if p.scheme not in ("http", "https") or p.netloc.lower() != "github.com":
        return url

    parts = [seg for seg in p.path.split("/") if seg]
    # Expect: OWNER / REPO / <mode> / <ref> / <path...>
    if len(parts) >= 4:
        owner, repo, mode, ref = parts[0], parts[1], parts[2], parts[3]

        # 1) blob -> raw (same host)
        if mode == "blob":
            parts[2] = "raw"
            new_path = "/" + "/".join(parts)
            p2 = p._replace(path=new_path)
            return urlunparse(p2)

        # 2) tree/<branch>[/subpath]#readme -> raw.githubusercontent.com/.../refs/heads/<branch>/[subpath/]README.md
        if mode == "tree" and (p.fragment or "").lower() == "readme":
            branch = ref
            subpath = "/".join(parts[4:])
            prefix = f"{subpath}/" if subpath else ""
            raw = f"https://raw.githubusercontent.com/{owner}/{repo}/refs/heads/{branch}/{prefix}README.md"
            return raw

    return url


def read_url(url: str, headers: dict[str, str], insecure: bool) -> str:
    url = rewrite_github_url(url)
    req = urllib.request.Request(url, headers=headers)

    if insecure:
        ctx = ssl._create_unverified_context()
    else:
        ctx = ssl.create_default_context(cafile=certifi.where())

    try:
        with urllib.request.urlopen(req, context=ctx) as resp:
            charset = resp.headers.get_content_charset() or "utf-8"
            return resp.read().decode(charset, errors="replace")
    except HTTPError as e:
        body = ""
        try:
            body = e.read().decode("utf-8", errors="replace")
        except Exception:
            pass
        raise RuntimeError(
            f"HTTP error {e.code} {e.reason} for {url}\n{body}".rstrip()
        ) from e
    except URLError as e:
        raise RuntimeError(f"URL error for {url}: {e.reason}") from e


def read_source(source: str, headers: dict[str, str], insecure: bool) -> str:
    if source == "-" or source == "":
        return sys.stdin.read()

    if source.startswith(("http://", "https://")):
        return read_url(source, headers, insecure)

    with open(source, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="mdview.py")
    ap.add_argument(
        "source",
        nargs="?",
        default="-",
        help="URL, file path, or '-' to read from stdin (default: '-')",
    )
    ap.add_argument(
        "-H",
        "--header",
        action="append",
        default=[],
        help="HTTP header, repeatable. Example: -H 'Authorization: token XYZ'",
    )
    ap.add_argument(
        "--no-wrap",
        action="store_true",
        help="Disable soft-wrapping inside the pager.",
    )
    ap.add_argument(
        "-k",
        "--insecure",
        action="store_true",
        help="Disable TLS certificate verification (NOT recommended).",
    )
    args = ap.parse_args(argv)

    try:
        headers = parse_headers(args.header)
        text = read_source(args.source, headers=headers, insecure=args.insecure)
    except Exception as e:
        print(f"mdview: {e}", file=sys.stderr)
        return 2

    console = Console()
    # Use Rich's built-in pager; user can quit with q.
    with console.pager(styles=True):
        console.print(Markdown(text), soft_wrap=not args.no_wrap)

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
