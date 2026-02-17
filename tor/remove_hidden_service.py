#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""Remove a hidden service entry from TOR_HIDDEN_SERVICES in the env file.

Usage:
  ./remove_hidden_service.py ENV_FILE name
"""
import sys, json

env_file = sys.argv[1]
name = sys.argv[2]

with open(env_file) as f:
    lines = f.read().splitlines()

removed = False
for i, line in enumerate(lines):
    if line.startswith("TOR_HIDDEN_SERVICES="):
        current = json.loads(line.split("=", 1)[1])
        filtered = [s for s in current if s[0] != name]
        removed = len(filtered) < len(current)
        lines[i] = "TOR_HIDDEN_SERVICES=" + json.dumps(filtered)
        break

with open(env_file, "w") as f:
    f.write("\n".join(lines) + "\n")

if removed:
    print(f"Removed hidden service: {name}")
    print(f"\nRun 'make reinstall' to apply changes.")
else:
    print(f"No hidden service named '{name}' found.")
