#!/usr/bin/env python3
"""drt_mcp.py - MCP tools for a drt device.

The host runs `drt --mcp CONTEXT` as a stdio MCP server. It forwards each
JSON-RPC line to this script inside the device, through
`podman exec -i drt-CONTEXT drt-device mcp`. Each call handles the lines
it is given and exits, so the host shim can keep answering while the
device is locked (with --offline, from a throwaway container).

Every tool maps to one `drt-device` command, so the device's console log,
idle timer and lease checks apply to MCP calls exactly as to `drt --exec`.

Only the Python standard library is used.
"""

from __future__ import annotations

import json
import subprocess
import sys

SERVER_VERSION = "1"
DEFAULT_PROTOCOL = "2025-06-18"

INSTRUCTIONS = """\
Tools for one d.rymcg.tech Docker server ("context"), run inside a drt
device the user has unlocked. Config changes (config_dist, reconfigure,
generated passwords) stay in the device until you call `save`; locking
also saves. Ask the user in conversation before anything destructive
(uninstall, destroy, reinstall of something others depend on, changing
routing/TLS/auth). If a tool says the device is locked, only the user can
unlock it (`drt --serve CONTEXT` at their workstation). Never ask for
their passphrase. See AGENTS.md in the d.rymcg.tech repo for conventions.
"""

_project = {"type": "string", "description": "Project directory name, e.g. whoami, traefik, forgejo (see list_projects)"}
_instance = {"type": "string", "description": "Instance name (default: default)"}
_service = {"type": "string", "description": "One compose service (default: all)"}
_timeout = {"type": "integer", "minimum": 1, "description": "Seconds to wait for health (TIMEOUT)"}


def _schema(props: dict, required: list[str] | None = None) -> dict:
    return {"type": "object", "properties": props, "required": required or [], "additionalProperties": False}


## name -> (description, input schema, annotations)
TOOLS: dict[str, tuple[str, dict, dict]] = {
    "device_status": ("Lease and idle time left on the device, and how many config keys are unsaved.",
                      _schema({}), {"readOnlyHint": True}),
    "device_diff": ("Names of config keys changed since the last save (no values).",
                    _schema({}), {"readOnlyHint": True}),
    "save": ("Encrypt unsaved config changes back to the SOPS config; the host then git commits and pushes it.",
             _schema({}), {"readOnlyHint": False, "destructiveHint": False}),
    "lock": ("Save, then shut the device down. Only the user can unlock it again.",
             _schema({}), {"readOnlyHint": False, "destructiveHint": False}),
    "list_projects": ("Projects available to configure and install.", _schema({}), {"readOnlyHint": True}),
    "list_instances": ("Configured instances of a project on this context.",
                       _schema({"project": _project}, ["project"]), {"readOnlyHint": True}),
    "status": ("Container status for one project (JSON), or for all projects if project is omitted.",
               _schema({"project": _project, "instance": _instance}), {"readOnlyHint": True}),
    "logs": ("Recent container logs for a project.",
             _schema({"project": _project, "service": _service, "instance": _instance,
                      "tail": {"type": "integer", "minimum": 1, "description": "Lines to return (default 200)"}},
                     ["project"]), {"readOnlyHint": True}),
    "get_config": ("Read one config variable. project 'root' reads the context-wide config (.env_CONTEXT).",
                   _schema({"project": _project, "var": {"type": "string"}, "instance": _instance},
                           ["project", "var"]), {"readOnlyHint": True}),
    "config_render": ("Render a project's full docker compose config, to check settings before installing.",
                      _schema({"project": _project, "instance": _instance}, ["project"]), {"readOnlyHint": True}),
    "config_dist": ("Create a new instance config from the project's .env-dist. Refuses if one exists.",
                    _schema({"project": _project, "instance": _instance}, ["project"]),
                    {"readOnlyHint": False, "destructiveHint": False}),
    "reconfigure": ("Set existing config variables. project 'root' changes the context-wide config. "
                    "Run install afterwards to apply.",
                    _schema({"project": _project, "instance": _instance,
                             "vars": {"type": "object", "additionalProperties": {"type": "string"},
                                      "description": "VAR_NAME -> value; each must already exist in the file"}},
                            ["project", "vars"]), {"readOnlyHint": False, "destructiveHint": False}),
    "install": ("Deploy a project (or apply config changes; recreates changed containers).",
                _schema({"project": _project, "instance": _instance, "timeout": _timeout}, ["project"]),
                {"readOnlyHint": False, "destructiveHint": False}),
    "reinstall": ("Uninstall then install a project (keeps volumes). Causes downtime.",
                  _schema({"project": _project, "instance": _instance, "timeout": _timeout}, ["project"]),
                  {"readOnlyHint": False, "destructiveHint": True}),
    "start": ("Start a project's containers.",
              _schema({"project": _project, "instance": _instance, "service": _service}, ["project"]),
              {"readOnlyHint": False, "destructiveHint": False}),
    "stop": ("Stop a project's containers.",
             _schema({"project": _project, "instance": _instance, "service": _service}, ["project"]),
             {"readOnlyHint": False, "destructiveHint": True}),
    "restart": ("Restart a project's containers.",
                _schema({"project": _project, "instance": _instance, "service": _service}, ["project"]),
                {"readOnlyHint": False, "destructiveHint": False}),
    "wait": ("Wait until a project's containers are running and healthy.",
             _schema({"project": _project, "instance": _instance, "timeout": _timeout}, ["project"]),
             {"readOnlyHint": True}),
    "uninstall": ("Remove a project's containers. Keeps data volumes.",
                  _schema({"project": _project, "instance": _instance}, ["project"]),
                  {"readOnlyHint": False, "destructiveHint": True}),
    "destroy": ("Remove a project's containers AND DELETE ITS DATA VOLUMES. Irreversible.",
                _schema({"project": _project, "instance": _instance}, ["project"]),
                {"readOnlyHint": False, "destructiveHint": True}),
    "run": ("Run any command inside the device (argv, no shell; use [\"bash\",\"-c\",\"...\"] for pipes). "
            "Full access to the server and every secret: prefer the specific tools.",
            _schema({"argv": {"type": "array", "items": {"type": "string"}, "minItems": 1}}, ["argv"]),
            {"readOnlyHint": False, "destructiveHint": True, "openWorldHint": True}),
}

## Request verb for each project tool (tool name -> verb)
VERB = {"list_projects": "list", "list_instances": "instances", "get_config": "get",
        "config_render": "config-render", "config_dist": "config-dist"}


def to_argv(name: str, args: dict) -> list[str]:
    """Translate a tool call to a drt-device command line."""
    if name == "device_status":
        return ["drt-device", "status"]
    if name == "device_diff":
        return ["drt-device", "diff"]
    if name == "save":
        return ["drt-device", "save"]
    if name == "lock":
        return ["drt-device", "lock"]
    if name == "run":
        argv = args.get("argv")
        if not isinstance(argv, list) or not argv or not all(isinstance(a, str) for a in argv):
            raise ValueError("argv must be a non-empty list of strings")
        return ["drt-device", "exec", *argv]
    verb = VERB.get(name, name)
    words: list[str] = []
    if "project" in args:
        words.append(str(args["project"]))
    if name == "get_config":
        words.append(str(args["var"]))
    for opt in ("instance", "service", "timeout", "tail"):
        if opt in args and args[opt] not in (None, ""):
            words.append(f"{opt}={args[opt]}")
    if name == "reconfigure":
        values = args.get("vars")
        if not isinstance(values, dict) or not values:
            raise ValueError("vars must be a non-empty object of VAR_NAME -> value")
        for key, value in values.items():
            words.append(f"{key}={value}")
    return ["drt-device", "exec", "request", verb, *words]


def call_tool(name: str, args: dict, offline: bool) -> dict:
    if name not in TOOLS:
        return {"content": [{"type": "text", "text": f"unknown tool: {name}"}], "isError": True}
    if offline:
        return {"content": [{"type": "text", "text":
                "The drt device is locked (not running). Only the user can unlock it, "
                "by running `drt --serve CONTEXT` at their workstation. Ask them to; "
                "never ask for their passphrase."}], "isError": True}
    try:
        argv = to_argv(name, args or {})
    except (KeyError, ValueError) as e:
        return {"content": [{"type": "text", "text": f"invalid arguments: {e}"}], "isError": True}
    proc = subprocess.run(argv, stdin=subprocess.DEVNULL, capture_output=True, text=True)
    text = proc.stdout
    if proc.stderr.strip():
        text += ("\n" if text else "") + proc.stderr
    return {"content": [{"type": "text", "text": text.strip() or f"exit code {proc.returncode}"}],
            "isError": proc.returncode != 0}


def handle(msg: dict, offline: bool) -> dict | None:
    method = msg.get("method")
    msg_id = msg.get("id")
    if msg_id is None:  # notification
        return None
    if method == "initialize":
        version = (msg.get("params") or {}).get("protocolVersion") or DEFAULT_PROTOCOL
        result = {"protocolVersion": version, "capabilities": {"tools": {}},
                  "serverInfo": {"name": "drt", "version": SERVER_VERSION}, "instructions": INSTRUCTIONS}
    elif method == "ping":
        result = {}
    elif method == "tools/list":
        result = {"tools": [{"name": n, "description": d, "inputSchema": s, "annotations": a}
                            for n, (d, s, a) in TOOLS.items()]}
    elif method == "tools/call":
        params = msg.get("params") or {}
        result = call_tool(params.get("name", ""), params.get("arguments") or {}, offline)
    else:
        return {"jsonrpc": "2.0", "id": msg_id, "error": {"code": -32601, "message": f"method not found: {method}"}}
    return {"jsonrpc": "2.0", "id": msg_id, "result": result}


def main() -> int:
    offline = "--offline" in sys.argv[1:]
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            out = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "parse error"}}
        else:
            out = handle(msg, offline) if isinstance(msg, dict) else None
        if out is not None:
            sys.stdout.write(json.dumps(out) + "\n")
            sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
