#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pydantic>=2.0"]
# ///
"""
request.py - Programmatic request handler for d.rymcg.tech

Accepts JSON on stdin describing actions to perform on d.rymcg.tech projects.
Validates input with Pydantic, builds commands, and executes them.

Usage:
    echo '{"project": "whoami", "action": "install"}' | d.rymcg.tech request
    echo '[{"project": "whoami", "action": "install"}]' | d.rymcg.tech request --dry-run
    echo '{"project": "whoami", "action": "status"}' | d.rymcg.tech request --validate-only
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from enum import Enum
from pathlib import Path
from typing import Any

from pydantic import BaseModel, field_validator, model_validator


class RequestAction(str, Enum):
    install = "install"
    uninstall = "uninstall"
    destroy = "destroy"
    reinstall = "reinstall"
    config_dist = "config-dist"
    reconfigure = "reconfigure"
    start = "start"
    stop = "stop"
    restart = "restart"
    status = "status"
    wait = "wait"


DESTRUCTIVE_ACTIONS = {
    RequestAction.uninstall,
    RequestAction.destroy,
    RequestAction.reinstall,
}

JSON_OUTPUT_ACTIONS = {
    RequestAction.status,
}

QUIET_ACTIONS = {
    RequestAction.install,
    RequestAction.uninstall,
    RequestAction.destroy,
    RequestAction.reinstall,
    RequestAction.config_dist,
    RequestAction.reconfigure,
    RequestAction.start,
    RequestAction.stop,
    RequestAction.restart,
    RequestAction.wait,
}


class RequestItem(BaseModel):
    project: str
    action: RequestAction
    instance: str = "default"
    config_vars: dict[str, str] | None = None

    @field_validator("project")
    @classmethod
    def validate_project(cls, v: str) -> str:
        if "/" in v:
            raise ValueError("project name must not contain '/'")
        if v.startswith(".") or v.startswith("_"):
            raise ValueError("project name must not start with '.' or '_'")
        if not v:
            raise ValueError("project name must not be empty")
        return v

    @model_validator(mode="after")
    def check_reconfigure_has_config_vars(self) -> "RequestItem":
        if self.action == RequestAction.reconfigure and not self.config_vars:
            raise ValueError("reconfigure action requires config_vars")
        return self


class CommandResult(BaseModel):
    project: str
    action: str
    instance: str
    success: bool
    exit_code: int
    command: list[str]
    stdout: str | None = None
    stderr: str | None = None
    skipped: bool
    error: str | None
    data: Any = None


def parse_requests(raw_json: str) -> list[RequestItem]:
    data = json.loads(raw_json)
    if isinstance(data, dict):
        data = [data]
    if not isinstance(data, list):
        raise ValueError("Input must be a JSON object or array of objects")
    return [RequestItem(**item) for item in data]


def get_root_dir() -> Path:
    env_path = os.environ.get("D_RYMCG_TECH_PATH")
    if env_path:
        return Path(env_path)
    return Path(__file__).parent.parent


def get_cli_path() -> str:
    sibling = Path(__file__).parent / "d.rymcg.tech"
    if sibling.exists():
        return str(sibling)
    found = shutil.which("d.rymcg.tech")
    if found:
        return found
    return "d.rymcg.tech"


def validate_project_dir(root: Path, project: str) -> str | None:
    if re.match(r"^-+$", project):
        makefile = root / "Makefile"
        if not makefile.exists():
            return f"Root directory {root} has no Makefile"
        return None
    project_dir = root / project
    if not project_dir.is_dir():
        return f"Project directory '{project}' does not exist"
    makefile = project_dir / "Makefile"
    if not makefile.exists():
        return f"Project '{project}' has no Makefile"
    return None


def build_commands(
    req: RequestItem, cli_path: str
) -> list[tuple[list[str], dict[str, str]]]:
    """Returns list of (command_args, extra_env) tuples."""
    commands: list[tuple[list[str], dict[str, str]]] = []

    if req.action == RequestAction.reconfigure and req.config_vars:
        for key, value in req.config_vars.items():
            cmd = [cli_path, "make", req.project, "reconfigure", f"var={key}={value}"]
            if req.instance != "default":
                cmd.append(f"instance={req.instance}")
            commands.append((cmd, {}))
    else:
        target = req.action.value
        cmd = [cli_path, "make", req.project, target]
        if req.instance != "default":
            cmd.append(f"instance={req.instance}")
        if req.action == RequestAction.status:
            cmd.append("FORMAT=json")
        env = {}
        if req.action in DESTRUCTIVE_ACTIONS:
            env["YES"] = "yes"
        commands.append((cmd, env))

    return commands


def execute_request(
    req: RequestItem,
    cli_path: str,
    root: Path,
    dry_run: bool = False,
) -> list[CommandResult]:
    results: list[CommandResult] = []

    dir_error = validate_project_dir(root, req.project)
    if dir_error:
        results.append(
            CommandResult(
                project=req.project,
                action=req.action.value,
                instance=req.instance,
                success=False,
                exit_code=1,
                command=[],
                stdout="",
                stderr="",
                skipped=False,
                error=dir_error,
            )
        )
        return results

    commands = build_commands(req, cli_path)

    for cmd, extra_env in commands:
        if dry_run:
            results.append(
                CommandResult(
                    project=req.project,
                    action=req.action.value,
                    instance=req.instance,
                    success=True,
                    exit_code=0,
                    command=cmd,
                    stdout="",
                    stderr="",
                    skipped=True,
                    error=None,
                )
            )
        else:
            run_env = os.environ.copy()
            run_env.update(extra_env)
            try:
                proc = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=300,
                    env=run_env,
                )
                data = None
                stdout = proc.stdout
                stderr = proc.stderr
                if req.action in JSON_OUTPUT_ACTIONS and proc.returncode == 0 and proc.stdout.strip():
                    try:
                        data = json.loads(proc.stdout)
                        stdout = None
                    except json.JSONDecodeError:
                        pass
                elif req.action in QUIET_ACTIONS and proc.returncode == 0:
                    stdout = None
                    stderr = None
                results.append(
                    CommandResult(
                        project=req.project,
                        action=req.action.value,
                        instance=req.instance,
                        success=proc.returncode == 0,
                        exit_code=proc.returncode,
                        command=cmd,
                        stdout=stdout,
                        stderr=stderr,
                        data=data,
                        skipped=False,
                        error=None,
                    )
                )
            except subprocess.TimeoutExpired:
                results.append(
                    CommandResult(
                        project=req.project,
                        action=req.action.value,
                        instance=req.instance,
                        success=False,
                        exit_code=1,
                        command=cmd,
                        stdout="",
                        stderr="",
                        skipped=False,
                        error="Command timed out after 300 seconds",
                    )
                )
            except Exception as e:
                results.append(
                    CommandResult(
                        project=req.project,
                        action=req.action.value,
                        instance=req.instance,
                        success=False,
                        exit_code=1,
                        command=cmd,
                        stdout="",
                        stderr="",
                        skipped=False,
                        error=str(e),
                    )
                )

    return results


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Execute d.rymcg.tech requests from JSON input on stdin"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands that would be executed without running them",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Validate JSON input and print parsed requests, no execution",
    )
    args = parser.parse_args()

    raw = sys.stdin.read()
    if not raw.strip():
        json.dump({"valid": False, "error": "empty_input", "details": "No JSON input provided on stdin"}, sys.stdout, indent=2)
        print()
        sys.exit(1)

    try:
        requests = parse_requests(raw)
    except (json.JSONDecodeError, ValueError, Exception) as e:
        json.dump({"valid": False, "error": "validation_error", "details": str(e)}, sys.stdout, indent=2)
        print()
        sys.exit(1)

    if args.validate_only:
        json.dump(
            {
                "valid": True,
                "requests": [r.model_dump(mode="json") for r in requests],
            },
            sys.stdout,
            indent=2,
        )
        print()
        sys.exit(0)

    root = get_root_dir()
    cli_path = get_cli_path()

    all_results: list[CommandResult] = []
    for req in requests:
        results = execute_request(req, cli_path, root, args.dry_run)
        all_results.extend(results)
        if any(not r.success for r in results):
            break

    all_success = all(r.success for r in all_results)
    json.dump(
        {
            "success": all_success,
            "dry_run": args.dry_run,
            "results": [r.model_dump(mode="json") for r in all_results],
        },
        sys.stdout,
        indent=2,
    )
    print()
    sys.exit(0 if all_success else 1)


if __name__ == "__main__":
    main()
