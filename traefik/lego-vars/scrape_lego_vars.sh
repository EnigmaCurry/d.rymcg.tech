#!/usr/bin/env bash
set -euo pipefail

export WORKDIR="${1:-/tmp/lego-envscan}"
export REPO_URL="https://github.com/go-acme/lego.git"
# absolute path to this script's directory
export SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

rm -rf "$WORKDIR"
git clone --depth=1 "$REPO_URL" "$WORKDIR"

uv run python3 - <<'PY'
import os, sys, re, pathlib, glob

# --- setup paths from env ---
root = pathlib.Path(os.environ["WORKDIR"])
script_dir = pathlib.Path(os.environ["SCRIPT_DIR"])

# --- TOML loader (tomllib on 3.11+, else tomli if available) ---
try:
    import tomllib  # py311+
except ModuleNotFoundError:
    try:
        import tomli as tomllib  # fallback
    except ModuleNotFoundError:
        print("Error: need Python 3.11+ (tomllib) or 'tomli' installed to parse TOML.", file=sys.stderr)
        sys.exit(2)

dns_dir = root / "providers" / "dns"
if not dns_dir.is_dir():
    print(f"Error: {dns_dir} not found; repo layout may have changed.", file=sys.stderr)
    sys.exit(2)

envvars = set()
VALID = re.compile(r'^[A-Z][A-Z0-9_]*$')

# Each provider dir contains <name>/<name>.toml
for provider_dir in dns_dir.iterdir():
    if not provider_dir.is_dir():
        continue
    name = provider_dir.name
    toml_path = provider_dir / f"{name}.toml"
    if not toml_path.is_file():
        # tolerate future variations: try any single *.toml
        matches = list(provider_dir.glob("*.toml"))
        if len(matches) != 1:
            continue
        toml_path = matches[0]

    try:
        with open(toml_path, "rb") as f:
            data = tomllib.load(f)
    except Exception as e:
        print(f"Warning: failed to parse {toml_path}: {e}", file=sys.stderr)
        continue

    # The section is "Configuration" (sometimes case varies, be lenient)
    cfg = (
        data.get("Configuration")
        or data.get("configuration")
        or data.get("CONFIGURATION")
        or {}
    )

    # Collect keys from all subtables under Configuration.*
    # e.g. Credentials, Additional, DNS01, etc.
    for key, sub in cfg.items():
        if isinstance(sub, dict):
            for env_key in sub.keys():
                if isinstance(env_key, str) and VALID.match(env_key):
                    envvars.add(env_key)

# Sort, write to SCRIPT_DIR/lego-vars.txt, also print to stdout
outpath = script_dir / "lego-vars.txt"
sorted_vars = sorted(envvars)
with open(outpath, "w") as f:
    for v in sorted_vars:
        f.write(v + "\n")

for v in sorted_vars:
    print(v, flush=False)

print(f"Wrote {outpath} ({len(sorted_vars)} vars)", file=sys.stderr)
PY
