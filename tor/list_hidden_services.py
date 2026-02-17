#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""List configured hidden services from TOR_HIDDEN_SERVICES in the env file."""
import sys, json

env_file = sys.argv[1]

services = []
onion_hosts = {}

with open(env_file) as f:
    for line in f:
        line = line.strip()
        if line.startswith("TOR_HIDDEN_SERVICES="):
            services = json.loads(line.split("=", 1)[1])
        elif line.startswith("TOR_ONION_HOSTS="):
            onion_hosts = json.loads(line.split("=", 1)[1])

if not services:
    print("No hidden services configured.")
    sys.exit(0)

for svc in services:
    name = svc[0]
    onion = onion_hosts.get(name, "")
    if len(svc) == 2:
        if onion:
            print(f"  {name}  HTTP  {svc[1]}  http://{onion}")
        else:
            print(f"  {name}  HTTP  {svc[1]}  (onion not yet assigned)")
    elif len(svc) == 3:
        if onion:
            print(f"  {name}  TCP   {onion}:{svc[1]} -> localhost:{svc[2]}")
        else:
            print(f"  {name}  TCP   .onion:{svc[1]} -> localhost:{svc[2]}  (onion not yet assigned)")
