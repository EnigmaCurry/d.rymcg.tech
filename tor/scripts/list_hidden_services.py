#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""List configured hidden services.

Reads TOR_HIDDEN_SERVICES from the env file.
Reads 'name hostname' pairs from stdin (piped from the running container).
"""
import sys, json

env_file = sys.argv[1]

services = []
with open(env_file) as f:
    for line in f:
        line = line.strip()
        if line.startswith("TOR_HIDDEN_SERVICES="):
            services = json.loads(line.split("=", 1)[1])

onion_hosts = {}
for line in sys.stdin:
    line = line.strip()
    if line:
        parts = line.split(None, 1)
        if len(parts) == 2:
            onion_hosts[parts[0]] = parts[1]

if not services:
    print("No hidden services configured.")
    sys.exit(0)

for svc in services:
    if isinstance(svc, str):
        name = svc
        onion = onion_hosts.get(name, "")
        if onion:
            print(f"  {name}  HTTP(web_plain)  http://{onion}")
        else:
            print(f"  {name}  HTTP(web_plain)  (not running)")
    elif len(svc) == 2:
        name = svc[0]
        hostname = svc[1]
        onion = onion_hosts.get(name, "")
        if onion:
            print(f"  {name}  HTTP(nginx->{hostname})  http://{onion}")
        else:
            print(f"  {name}  HTTP(nginx->{hostname})  (not running)")
    else:
        name = svc[0]
        onion = onion_hosts.get(name, "")
        if onion:
            print(f"  {name}  TCP  {onion}:{svc[1]} -> localhost:{svc[2]}")
        else:
            print(f"  {name}  TCP  .onion:{svc[1]} -> localhost:{svc[2]}  (not running)")
