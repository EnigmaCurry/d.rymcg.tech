#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""Read 'name hostname' pairs from stdin and update TOR_ONION_HOSTS in the env file."""
import sys, json

env_file = sys.argv[1]

pairs = {}
for line in sys.stdin:
    line = line.strip()
    if line:
        name, addr = line.split(None, 1)
        pairs[name] = addr

onion_json = json.dumps(pairs)

with open(env_file) as f:
    lines = f.read().splitlines()

for i, line in enumerate(lines):
    if line.startswith("TOR_ONION_HOSTS="):
        lines[i] = "TOR_ONION_HOSTS=" + onion_json

with open(env_file, "w") as f:
    f.write("\n".join(lines) + "\n")

for name, addr in pairs.items():
    print(f"{name}: {addr}")
print(f"\nUpdated {env_file}:")
print(f"TOR_ONION_HOSTS={onion_json}")
print(f"\nConfigure each service with its .onion address as TRAEFIK_HOST.")
