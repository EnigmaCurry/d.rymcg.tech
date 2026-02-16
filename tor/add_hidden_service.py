#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""Add a hidden service entry to TOR_HIDDEN_SERVICES in the env file.

Usage:
  ./add_hidden_service.py ENV_FILE '["name", "docker-service"]'        # HTTP
  ./add_hidden_service.py ENV_FILE '["name", tor_port, traefik_port]'  # TCP

Adds the entry if no service with that name exists.
Replaces the entry if a service with that name already exists.
"""
import sys, json

env_file = sys.argv[1]
new_entry = json.loads(sys.argv[2])
name = new_entry[0]

with open(env_file) as f:
    lines = f.read().splitlines()

for i, line in enumerate(lines):
    if line.startswith("TOR_HIDDEN_SERVICES="):
        current = json.loads(line.split("=", 1)[1])
        # Remove any existing entry with the same name
        filtered = [s for s in current if s[0] != name]
        replaced = len(filtered) < len(current)
        filtered.append(new_entry)
        lines[i] = "TOR_HIDDEN_SERVICES=" + json.dumps(filtered)
        break

with open(env_file, "w") as f:
    f.write("\n".join(lines) + "\n")

action = "Replaced" if replaced else "Added"
if len(new_entry) == 2:
    print(f"{action} HTTP hidden service: {name} -> {new_entry[1]}")
elif len(new_entry) == 3:
    print(f"{action} TCP hidden service: {name} (tor port {new_entry[1]} -> localhost:{new_entry[2]})")

print(f"\nRun 'make reinstall' to apply changes.")
