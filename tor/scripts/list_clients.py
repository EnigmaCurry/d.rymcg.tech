#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""List clients and their authorized services.

Usage:
  ./list_clients.py PROJECT_NAME [SERVICE_NAME]
"""
import sys, subprocess, re

project_name = sys.argv[1]
service_name = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else ""
volume = f"{project_name}_tor_data"

if service_name and not re.fullmatch(r'[a-zA-Z0-9_-]+', service_name):
    print(f"Error: invalid service name '{service_name}'")
    sys.exit(1)

if service_name:
    # List clients authorized for a specific service
    result = subprocess.run(
        ["docker", "run", "--rm", "-v", f"{volume}:/data:ro", "alpine",
         "sh", "-c",
         f"ls /data/{service_name}/authorized_clients/*.auth 2>/dev/null | "
         f"sed 's|.*/||;s|\\.auth$||'"],
        capture_output=True, text=True
    )
    clients = [c for c in result.stdout.strip().splitlines() if c]
    if clients:
        print(f"Clients authorized for '{service_name}':")
        for c in sorted(clients):
            print(f"  {c}")
    else:
        print(f"No clients authorized for '{service_name}'.")
else:
    # List all clients and which services each is authorized for
    result = subprocess.run(
        ["docker", "run", "--rm", "-v", f"{volume}:/data:ro", "alpine",
         "sh", "-c",
         "ls /data/.clients/ 2>/dev/null"],
        capture_output=True, text=True
    )
    clients = [c for c in result.stdout.strip().splitlines() if c]
    if not clients:
        print("No clients configured.")
        sys.exit(0)

    # For each client, find authorized services
    result = subprocess.run(
        ["docker", "run", "--rm", "-v", f"{volume}:/data:ro", "alpine",
         "sh", "-c",
         "for client in /data/.clients/*/; do "
         "  name=$(basename \"$client\"); "
         "  svcs=''; "
         "  for auth in /data/*/authorized_clients/${name}.auth; do "
         "    [ -f \"$auth\" ] || continue; "
         "    svc=$(echo \"$auth\" | sed 's|/data/||;s|/authorized_clients/.*||'); "
         "    svcs=\"$svcs $svc\"; "
         "  done; "
         "  echo \"$name:$svcs\"; "
         "done"],
        capture_output=True, text=True
    )

    print("Clients:")
    for line in sorted(result.stdout.strip().splitlines()):
        if not line:
            continue
        name, svcs = line.split(":", 1)
        svcs = svcs.strip()
        if svcs:
            print(f"  {name}  ->  {svcs}")
        else:
            print(f"  {name}  (not authorized for any service)")
