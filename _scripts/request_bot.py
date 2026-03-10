#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["nats-py>=2.9", "openai>=1.0"]
# ///
"""NATS LLM Chatbot - bridges Matrix messages to an OpenAI-compatible LLM."""

import argparse
import asyncio
import json
import logging
import os
import re
import signal
import ssl
import sys

import nats
from nats.js.api import KeyValueConfig
from openai import AsyncOpenAI

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stderr,
)
log = logging.getLogger("request-bot")

DEFAULT_SYSTEM_PROMPT = (
    "You are a helpful assistant for d.rymcg.tech, a Docker-based self-hosting platform. "
    "Answer questions clearly and concisely. If you don't know something, say so."
)


def parse_args():
    p = argparse.ArgumentParser(
        description="NATS LLM chatbot bridging Matrix messages to an OpenAI-compatible LLM"
    )
    p.add_argument(
        "--nats-url",
        default=os.environ.get("DRT_REQUEST_BOT_NATS_URL", "nats://localhost:4222"),
        help="NATS server URL (default: nats://localhost:4222)",
    )
    p.add_argument(
        "--nats-subscribe-subject",
        default=os.environ.get("DRT_REQUEST_BOT_NATS_SUBSCRIBE_SUBJECT", "matrix.messages"),
        help="NATS subject to subscribe to (default: matrix.messages)",
    )
    p.add_argument(
        "--nats-publish-subject",
        default=os.environ.get("DRT_REQUEST_BOT_NATS_PUBLISH_SUBJECT", "matrix.responses"),
        help="NATS subject to publish responses to (default: matrix.responses)",
    )
    p.add_argument(
        "--nats-cert",
        default=os.environ.get("DRT_REQUEST_BOT_NATS_CERT"),
        help="Path to mTLS client certificate (required)",
    )
    p.add_argument(
        "--nats-key",
        default=os.environ.get("DRT_REQUEST_BOT_NATS_KEY"),
        help="Path to mTLS client private key (required)",
    )
    p.add_argument(
        "--nats-ca",
        default=os.environ.get("DRT_REQUEST_BOT_NATS_CA"),
        help="Path to CA certificate (optional)",
    )
    p.add_argument(
        "--nats-kv-bucket",
        default=os.environ.get("DRT_REQUEST_BOT_NATS_KV_BUCKET", "request_bot_history"),
        help="JetStream KV bucket name (default: request_bot_history)",
    )
    p.add_argument(
        "--history-ttl",
        type=int,
        default=int(os.environ.get("DRT_REQUEST_BOT_HISTORY_TTL", "86400")),
        help="Conversation history TTL in seconds (default: 86400 / 24h)",
    )
    p.add_argument(
        "--openai-base-url",
        default=os.environ.get("DRT_REQUEST_BOT_OPENAI_BASE_URL", "http://localhost:11434/v1"),
        help="OpenAI-compatible API base URL (default: http://localhost:11434/v1)",
    )
    p.add_argument(
        "--openai-api-key",
        default=os.environ.get("DRT_REQUEST_BOT_OPENAI_API_KEY", "unused"),
        help="OpenAI API key (default: unused)",
    )
    p.add_argument(
        "--openai-model",
        default=os.environ.get("DRT_REQUEST_BOT_OPENAI_MODEL", "Qwen/Qwen3.5-27B"),
        help="LLM model name (default: Qwen/Qwen3.5-27B)",
    )
    p.add_argument(
        "--openai-cert",
        default=os.environ.get("DRT_REQUEST_BOT_OPENAI_CERT"),
        help="Path to client certificate for OpenAI backend (optional)",
    )
    p.add_argument(
        "--openai-key",
        default=os.environ.get("DRT_REQUEST_BOT_OPENAI_KEY"),
        help="Path to client private key for OpenAI backend (optional)",
    )
    p.add_argument(
        "--openai-ca",
        default=os.environ.get("DRT_REQUEST_BOT_OPENAI_CA"),
        help="Path to CA certificate for OpenAI backend (optional)",
    )
    p.add_argument(
        "--system-prompt",
        default=os.environ.get("DRT_REQUEST_BOT_SYSTEM_PROMPT", DEFAULT_SYSTEM_PROMPT),
        help="System prompt for the LLM",
    )
    return p.parse_args()


def build_nats_tls(cert_path, key_path, ca_path=None):
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.load_cert_chain(cert_path, key_path)
    if ca_path:
        ctx.load_verify_locations(ca_path)
    else:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    return ctx


def build_openai_client(args):
    import httpx

    http_client = None
    if args.openai_cert and args.openai_key:
        ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ssl_ctx.load_cert_chain(args.openai_cert, args.openai_key)
        if args.openai_ca:
            ssl_ctx.load_verify_locations(args.openai_ca)
        else:
            ssl_ctx.check_hostname = False
            ssl_ctx.verify_mode = ssl.CERT_NONE
        http_client = httpx.AsyncClient(verify=ssl_ctx)

    return AsyncOpenAI(
        base_url=args.openai_base_url,
        api_key=args.openai_api_key,
        http_client=http_client,
    )


def sanitize_kv_key(user_id, room_id):
    """Create a valid NATS KV key from user_id and room_id."""
    def clean(s):
        return re.sub(r"[^a-zA-Z0-9_-]", "_", s)
    return f"{clean(user_id)}.{clean(room_id)}"


async def load_history(kv, key):
    try:
        entry = await kv.get(key)
        return json.loads(entry.value.decode())
    except nats.js.errors.KeyNotFoundError:
        return []
    except Exception as e:
        log.warning("Failed to load history for %s: %s", key, e)
        return []


async def store_history(kv, key, history):
    data = json.dumps(history).encode()
    await kv.put(key, data)


async def run(args):
    # Validate required NATS TLS args
    if not args.nats_cert or not args.nats_key:
        log.error("--nats-cert and --nats-key are required")
        sys.exit(1)

    tls_ctx = build_nats_tls(args.nats_cert, args.nats_key, args.nats_ca)
    openai_client = build_openai_client(args)

    nc = await nats.connect(args.nats_url, tls=tls_ctx)
    js = nc.jetstream()

    # Create or bind to KV bucket
    try:
        kv = await js.create_key_value(
            KeyValueConfig(
                bucket=args.nats_kv_bucket,
                ttl=args.history_ttl,
            )
        )
    except nats.js.errors.BucketNotFoundError:
        kv = await js.create_key_value(
            KeyValueConfig(
                bucket=args.nats_kv_bucket,
                ttl=args.history_ttl,
            )
        )

    log.info(
        "Connected to NATS %s | subscribe=%s publish=%s kv=%s model=%s",
        args.nats_url,
        args.nats_subscribe_subject,
        args.nats_publish_subject,
        args.nats_kv_bucket,
        args.openai_model,
    )

    async def handle_message(msg):
        try:
            data = json.loads(msg.data.decode())
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            log.warning("Invalid JSON message: %s", e)
            return

        # Validate Matrix message structure
        if data.get("type") != "m.room.message":
            return
        content = data.get("content", {})
        if content.get("msgtype") != "m.text":
            return

        user_id = data.get("user_id", "")
        room_id = data.get("room_id", "")
        body = content.get("body", "").strip()
        if not user_id or not room_id or not body:
            log.warning("Missing user_id, room_id, or body in message")
            return

        log.info("Message from %s in %s: %s", user_id, room_id, body[:100])

        key = sanitize_kv_key(user_id, room_id)
        history = await load_history(kv, key)

        # Append user message
        history.append({"role": "user", "content": body})

        # Build OpenAI messages
        messages = [{"role": "system", "content": args.system_prompt}]
        messages.extend({"role": h["role"], "content": h["content"]} for h in history)

        try:
            response = await openai_client.chat.completions.create(
                model=args.openai_model,
                messages=messages,
            )
            reply = response.choices[0].message.content
        except Exception as e:
            log.error("LLM error: %s", e)
            reply = "Sorry, I encountered an error processing your request."

        # Store updated history with assistant reply
        history.append({"role": "assistant", "content": reply})
        await store_history(kv, key, history)

        # Extract username for mention (e.g. @alice:example.com -> @alice)
        mention = user_id.split(":")[0] if ":" in user_id else user_id
        if not mention.startswith("@"):
            mention = f"@{mention}"

        response_payload = json.dumps({
            "room_id": room_id,
            "body": f"{mention}: {reply}",
        }).encode()
        await nc.publish(args.nats_publish_subject, response_payload)
        log.info("Response sent to %s in %s", user_id, room_id)

    sub = await nc.subscribe(args.nats_subscribe_subject, cb=handle_message)
    log.info("Subscribed, waiting for messages...")

    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, stop.set)

    await stop.wait()
    log.info("Shutting down...")
    await sub.unsubscribe()
    await nc.drain()
    await nc.close()


def main():
    args = parse_args()
    asyncio.run(run(args))


if __name__ == "__main__":
    main()
