#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""Add a hidden service entry to TOR_HIDDEN_SERVICES in the env file.

Usage:
  ./add_hidden_service.py ENV_FILE NAME              # HTTP
  ./add_hidden_service.py ENV_FILE NAME TOR:LOCAL    # TCP

Adds the entry if no service with that name exists.
Replaces the entry if a service with that name already exists.
"""
import sys, json

env_file = sys.argv[1]
name = sys.argv[2]
port = sys.argv[3] if len(sys.argv) > 3 else ""

if port:
    tor_port, local_port = port.split(":")
    new_entry = [name, int(tor_port), int(local_port)]
else:
    new_entry = name

def svc_name(s):
    return s if isinstance(s, str) else s[0]

with open(env_file) as f:
    lines = f.read().splitlines()

for i, line in enumerate(lines):
    if line.startswith("TOR_HIDDEN_SERVICES="):
        current = json.loads(line.split("=", 1)[1])
        filtered = [s for s in current if svc_name(s) != name]
        replaced = len(filtered) < len(current)
        filtered.append(new_entry)
        lines[i] = "TOR_HIDDEN_SERVICES=" + json.dumps(filtered)
        break

with open(env_file, "w") as f:
    f.write("\n".join(lines) + "\n")

action = "Replaced" if replaced else "Added"
if isinstance(new_entry, str):
    print(f"{action} HTTP hidden service: {name}")
else:
    print(f"{action} TCP hidden service: {name} (.onion:{new_entry[1]} -> localhost:{new_entry[2]})")

print(f"\nRun 'd.rymcg.tech make tor reinstall' to apply changes.")
