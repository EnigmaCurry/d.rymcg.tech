#!/usr/bin/env python3
"""drt_request.py - typed d.rymcg.tech verbs for a drt device.

One verb per invocation, with every argument on the command line, so
agent permission rules (Claude Code `Bash(...)` patterns, or per-tool MCP
permissions) can tell a `status` from a `destroy`. Prints one JSON
object and exits with the command's exit code.

Runs inside a drt device, through `drt-device exec request ...`:

    drt --exec CONTEXT -- request VERB [PROJECT] [ARGS...]

Verbs:
    list                                       projects you can configure
    instances PROJECT                          configured instances of a project
    status [PROJECT] [instance=NAME]           containers (all projects if omitted)
    logs PROJECT [service=NAME] [tail=N] [instance=NAME]
    get PROJECT|root VAR [instance=NAME]       read one config value
    config-render PROJECT [instance=NAME]      rendered docker compose config
    config-dist PROJECT [instance=NAME]        new config from .env-dist (never overwrites)
    reconfigure PROJECT|root VAR=VALUE... [instance=NAME]
    install|reinstall PROJECT [instance=NAME] [timeout=SEC]
    start|stop|restart PROJECT [service=NAME] [instance=NAME]
    wait PROJECT [instance=NAME] [timeout=SEC]
    uninstall|destroy PROJECT [instance=NAME]  (destroy deletes volumes)

PROJECT `root` means the context-wide config (.env_CONTEXT), for get and
reconfigure. Lowercase key=value words are options; uppercase VAR=VALUE
words are config variables.

Only the Python standard library is used, so this runs with any python3.
"""

from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import sys
from pathlib import Path

ROOT_DIR = Path(os.environ.get("D_RYMCG_TECH_PATH", "/home/user/git/vendor/enigmacurry/d.rymcg.tech"))
CLI = "d.rymcg.tech"

READ_VERBS = {"list", "instances", "status", "logs", "get", "config-render"}
CONFIG_VERBS = {"config-dist", "reconfigure"}
LIFECYCLE_VERBS = {"install", "reinstall", "start", "stop", "restart", "wait"}
DESTRUCTIVE_VERBS = {"uninstall", "destroy"}
VERBS = READ_VERBS | CONFIG_VERBS | LIFECYCLE_VERBS | DESTRUCTIVE_VERBS

## Options each verb accepts (lowercase key=value words)
VERB_OPTIONS = {
    "list": set(),
    "instances": set(),
    "status": {"instance"},
    "logs": {"instance", "service", "tail"},
    "get": {"instance"},
    "config-render": {"instance"},
    "config-dist": {"instance"},
    "reconfigure": {"instance"},
    "install": {"instance", "timeout"},
    "reinstall": {"instance", "timeout"},
    "start": {"instance", "service"},
    "stop": {"instance", "service"},
    "restart": {"instance", "service"},
    "wait": {"instance", "timeout"},
    "uninstall": {"instance"},
    "destroy": {"instance"},
}

## Keep agent transcripts small: long output is cut to its last part
MAX_OUTPUT_CHARS = 12000
DEFAULT_LOG_TAIL = 200
PROCESS_TIMEOUT = int(os.environ.get("DRT_REQUEST_TIMEOUT", "1800"))

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
INSTANCE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")
VAR_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


class RequestError(Exception):
    """A request that was refused before anything ran."""


def context() -> str:
    ctx = os.environ.get("DRT_CONTEXT", "")
    if not ctx:
        raise RequestError("DRT_CONTEXT is not set; run this inside a drt device")
    return ctx


def env_dir() -> Path:
    custom = os.environ.get("DRT_ENV_DIR")
    return Path(custom) if custom else ROOT_DIR


def project_env_file(project: str, instance: str) -> Path:
    return env_dir() / project / f".env_{context()}_{instance}"


def root_env_file() -> Path:
    return env_dir() / f".env_{context()}"


def list_projects() -> list[str]:
    projects = []
    for d in sorted(ROOT_DIR.iterdir()):
        if d.is_dir() and NAME_RE.match(d.name) and (d / ".env-dist").is_file() and (d / "Makefile").is_file():
            projects.append(d.name)
    return projects


def list_instances(project: str) -> list[str]:
    prefix = f".env_{context()}_"
    d = env_dir() / project
    if not d.is_dir():
        return []
    return sorted(f.name[len(prefix):] for f in d.iterdir() if f.name.startswith(prefix))


def check_project(project: str, allow_root: bool = False) -> None:
    if allow_root and project == "root":
        return
    if not NAME_RE.match(project):
        raise RequestError(f"invalid project name: {project!r}")
    pdir = ROOT_DIR / project
    if not (pdir / "Makefile").is_file() or not (pdir / ".env-dist").is_file():
        raise RequestError(f"no such project: {project!r} (see: request list)")


def env_keys(path: Path) -> set[str]:
    keys = set()
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            keys.add(line.split("=", 1)[0])
    return keys


def parse_args(verb: str, words: list[str]) -> tuple[list[str], dict[str, str], dict[str, str]]:
    """Split words into positionals, options (lowercase k=v) and config vars (VAR=v)."""
    positionals: list[str] = []
    options: dict[str, str] = {}
    config_vars: dict[str, str] = {}
    for w in words:
        if "=" in w:
            key, value = w.split("=", 1)
            if key in VERB_OPTIONS[verb]:
                options[key] = value
                continue
            if verb == "reconfigure" and VAR_RE.match(key) and key != key.lower():
                config_vars[key] = value
                continue
            raise RequestError(f"{verb}: unknown option {key!r} (accepts: {', '.join(sorted(VERB_OPTIONS[verb])) or 'none'})")
        positionals.append(w)
    if "instance" in options and not INSTANCE_RE.match(options["instance"]):
        raise RequestError(f"invalid instance name: {options['instance']!r}")
    for key in ("timeout", "tail"):
        if key in options and not options[key].isdigit():
            raise RequestError(f"{key} must be a whole number of seconds/lines")
    if "service" in options and not NAME_RE.match(options["service"]):
        raise RequestError(f"invalid service name: {options['service']!r}")
    return positionals, options, config_vars


def run(cmd: list[str], extra_env: dict[str, str] | None = None) -> tuple[int, str, str]:
    env = os.environ.copy()
    env.update(extra_env or {})
    proc = subprocess.Popen(
        cmd,
        cwd=ROOT_DIR,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
        start_new_session=True,
    )
    try:
        out, err = proc.communicate(timeout=PROCESS_TIMEOUT)
    except subprocess.TimeoutExpired:
        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGKILL):
            try:
                os.killpg(proc.pid, sig)
                out, err = proc.communicate(timeout=5)
                break
            except subprocess.TimeoutExpired:
                continue
        else:
            out, err = "", ""
        return 124, out or "", (err or "") + f"\ntimed out after {PROCESS_TIMEOUT}s"
    return proc.returncode, out, err


def clip(text: str, limit: int = MAX_OUTPUT_CHARS) -> tuple[str, bool]:
    if len(text) <= limit:
        return text, False
    return "...\n" + text[-limit:], True


def dotenv_cmd(env_file: Path, *args: str) -> list[str]:
    return [str(ROOT_DIR / "_scripts" / "dotenv"), "-f", str(env_file), *args]


def make_cmd(project: str, target: str, options: dict[str, str], *extra: str) -> list[str]:
    cmd = [CLI, "make", project, target]
    if options.get("instance", "default") != "default":
        cmd.append(f"instance={options['instance']}")
    if "service" in options:
        cmd.append(f"service={options['service']}")
    if "timeout" in options:
        cmd.append(f"TIMEOUT={options['timeout']}")
    cmd.extend(extra)
    return cmd


def handle(verb: str, words: list[str]) -> dict:
    if verb not in VERBS:
        raise RequestError(f"unknown verb: {verb!r} (verbs: {', '.join(sorted(VERBS))})")
    positionals, options, config_vars = parse_args(verb, words)
    instance = options.get("instance", "default")
    result: dict = {"verb": verb, "context": context()}

    if verb == "list":
        if positionals:
            raise RequestError("list takes no arguments")
        result.update(ok=True, exit_code=0, data=list_projects())
        return result

    project = positionals[0] if positionals else None
    if project is not None:
        result["project"] = project
    if verb != "status" and project is None:
        raise RequestError(f"{verb}: PROJECT is required")
    expected = {"get": 2}.get(verb, 1)
    if verb == "status":
        expected = len(positionals)  # 0 or 1
        if expected > 1:
            raise RequestError("status takes at most one PROJECT")
    if len(positionals) != expected:
        raise RequestError(f"{verb}: expected {expected} positional argument(s), got {len(positionals)}")
    if project is not None:
        check_project(project, allow_root=verb in ("get", "reconfigure"))
        if project != "root":
            result["instance"] = instance

    if verb == "instances":
        result.update(ok=True, exit_code=0, data=list_instances(project))
        return result

    extra_env: dict[str, str] = {}
    json_output = False

    if verb == "status":
        if project is None:
            cmd = [CLI, "status"]
        else:
            cmd = make_cmd(project, "status", options, "FORMAT=json")
            json_output = True
    elif verb == "logs":
        cmd = make_cmd(project, "logs-out", options)
    elif verb == "get":
        var = positionals[1]
        if not VAR_RE.match(var):
            raise RequestError(f"invalid variable name: {var!r}")
        env_file = root_env_file() if project == "root" else project_env_file(project, instance)
        if not env_file.is_file():
            raise RequestError(f"{project} instance {instance!r} isn't configured ({env_file.name} missing)"
                               if project != "root" else f"{env_file.name} doesn't exist")
        if var not in env_keys(env_file):
            raise RequestError(f"{var} is not in {env_file.name}")
        ## Read the file directly, not through make, so the value comes back verbatim
        cmd = dotenv_cmd(env_file, "get", var)
    elif verb == "config-render":
        cmd = make_cmd(project, "config-render", options)
    elif verb == "config-dist":
        env_file = project_env_file(project, instance)
        if env_file.exists():
            raise RequestError(
                f"{env_file.name} already exists; config-dist would overwrite it. "
                f"Change it with: request reconfigure {project} VAR=VALUE"
                + ("" if instance == "default" else f" instance={instance}")
            )
        cmd = make_cmd(project, "config-dist", options)
    elif verb == "reconfigure":
        if not config_vars:
            raise RequestError("reconfigure: give at least one VAR=VALUE")
        env_file = root_env_file() if project == "root" else project_env_file(project, instance)
        if not env_file.is_file():
            raise RequestError(
                f"{env_file.name} doesn't exist"
                + ("" if project == "root" else f"; create it first with: request config-dist {project}")
            )
        unknown = sorted(set(config_vars) - env_keys(env_file))
        if unknown:
            raise RequestError(f"not in {env_file.name} (check {project}/.env-dist): {', '.join(unknown)}")
        bad = sorted(k for k, v in config_vars.items() if "\n" in v or "\r" in v)
        if bad:
            raise RequestError(f"values can't contain newlines: {', '.join(bad)}")
        steps = []
        for key, value in config_vars.items():
            ## Write the file directly, not through make: make would expand
            ## `$` in the value (`$$` -> `$`), breaking htpasswd hashes (#782)
            cmd = dotenv_cmd(env_file, "set", f"{key}={value}")
            code, out, err = run(cmd)
            steps.append({"var": key, "exit_code": code})
            if code != 0:
                stderr, _ = clip(err or out)
                result.update(ok=False, exit_code=code, command=cmd, stderr=stderr, data=steps)
                return result
        result.update(ok=True, exit_code=0, data={"set": sorted(config_vars)},
                      note="Run install to apply. Changes live in the device until you save.")
        return result
    else:
        # lifecycle and destructive verbs
        if project_env_file(project, instance).is_file() is False:
            raise RequestError(f"{project} instance {instance!r} isn't configured; run: request config-dist {project}")
        cmd = make_cmd(project, verb, options)
        if verb in DESTRUCTIVE_VERBS or verb == "reinstall":
            # The agent's permission system has already asked the user
            extra_env["YES"] = "yes"

    code, out, err = run(cmd, extra_env)
    result.update(ok=code == 0, exit_code=code, command=cmd)
    if json_output and code == 0:
        try:
            result["data"] = json.loads(out or "[]")
            out = ""
        except json.JSONDecodeError:
            pass
    if verb == "logs":
        tail = int(options.get("tail", DEFAULT_LOG_TAIL))
        lines = out.splitlines()
        if len(lines) > tail:
            out = "\n".join(lines[-tail:])
            result["truncated"] = True
    if out:
        result["stdout"], cut = clip(out)
        if cut:
            result["truncated"] = True
    if err:
        result["stderr"], _ = clip(err, 4000)
    return result


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__.strip())
        return 0
    verb, words = argv[0], argv[1:]
    try:
        result = handle(verb, words)
    except RequestError as e:
        result = {"verb": verb, "ok": False, "exit_code": 64, "error": str(e)}
    print(json.dumps(result, indent=2))
    return int(result.get("exit_code", 1))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
