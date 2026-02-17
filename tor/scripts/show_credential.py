#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""Display client credentials for Tor v3 client authorization.

Usage:
  ./show_credential.py PROJECT_NAME CLIENT_NAME
"""
import sys, subprocess, re

project_name = sys.argv[1]
client_name = sys.argv[2]
volume = f"{project_name}_tor_data"

if not re.fullmatch(r'[a-zA-Z0-9_-]+', client_name):
    print(f"Error: invalid client name '{client_name}'")
    sys.exit(1)

# Read private key
result = subprocess.run(
    ["docker", "run", "--rm", "-v", f"{volume}:/data:ro", "alpine",
     "cat", f"/data/.clients/{client_name}/private"],
    capture_output=True, text=True
)
if result.returncode != 0:
    print(f"Error: client '{client_name}' not found.")
    sys.exit(1)
private_key = result.stdout.strip()

# Find all services this client is authorized for and read their hostnames
result = subprocess.run(
    ["docker", "run", "--rm", "-v", f"{volume}:/data:ro", "alpine",
     "sh", "-c",
     f"for auth in /data/*/authorized_clients/{client_name}.auth; do "
     f"  [ -f \"$auth\" ] || continue; "
     f"  svc=$(echo \"$auth\" | sed 's|/data/||;s|/authorized_clients/.*||'); "
     f"  hostname=''; "
     f"  [ -f \"/data/$svc/hostname\" ] && hostname=$(cat \"/data/$svc/hostname\"); "
     f"  echo \"$svc $hostname\"; "
     f"done"],
    capture_output=True, text=True
)

services = []
for line in result.stdout.strip().splitlines():
    if line:
        parts = line.split(None, 1)
        if len(parts) == 2:
            services.append((parts[0], parts[1].strip()))

if services:
    print(f"Client: {client_name}")
    print(f"Private key: {private_key}")
    print()
    for svc_name, onion in services:
        onion_addr = onion.replace(".onion", "")
        credential = f"{onion_addr}:descriptor:x25519:{private_key}"
        print(f"  {svc_name} ({onion}):")
        print(f"    {credential}")
    print()
    print("Tor Browser will prompt for the private key when you visit the .onion address.")
    print("For other Tor clients, save the credential line to a .auth_private file")
    print("in your ClientOnionAuthDir.")
else:
    print(f"Client: {client_name}")
    print(f"Private key: {private_key}")
    print()
    print("Not authorized for any service yet.")
    print(f"Run 'd.rymcg.tech make tor authorize-client svc=SERVICE client={client_name}' to grant access.")
