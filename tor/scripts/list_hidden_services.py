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
else:
    for svc in services:
        name = svc[0]
        onion = onion_hosts.get(name, "")
        if len(svc) == 2:
            if onion:
                print(f"  {name}  HTTP  {svc[1]}  http://{onion}")
            else:
                print(f"  {name}  HTTP  {svc[1]}  (not running)")
        elif len(svc) == 3:
            if onion:
                print(f"  {name}  TCP   {onion}:{svc[1]} -> localhost:{svc[2]}")
            else:
                print(f"  {name}  TCP   .onion:{svc[1]} -> localhost:{svc[2]}  (not running)")

print()
print("Add an HTTP service:  d.rymcg.tech make tor add-hidden-service svc=project-instance-service")
print("                e.g.  d.rymcg.tech make tor add-hidden-service svc=whoami-default-whoami")
print("Add a TCP service:    d.rymcg.tech make tor add-hidden-service svc=name port=TOR_PORT:LOCAL_PORT")
print("                e.g.  d.rymcg.tech make tor add-hidden-service svc=ssh port=22:22")
