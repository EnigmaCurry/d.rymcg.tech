#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""Delete a client and revoke access to all services.

Usage:
  ./remove_client.py PROJECT_NAME CLIENT_NAME
"""
import sys, subprocess, re

project_name = sys.argv[1]
client_name = sys.argv[2]
volume = f"{project_name}_tor_data"

if not re.fullmatch(r'[a-zA-Z0-9_-]+', client_name):
    print(f"Error: invalid client name '{client_name}'")
    sys.exit(1)

# Check if client exists
result = subprocess.run(
    ["docker", "run", "--rm", "-v", f"{volume}:/data:ro", "alpine",
     "test", "-d", f"/data/.clients/{client_name}"],
    capture_output=True
)
if result.returncode != 0:
    print(f"Error: client '{client_name}' not found.")
    sys.exit(1)

# Remove auth files from all services and delete client directory
subprocess.run(
    ["docker", "run", "--rm", "-v", f"{volume}:/data", "alpine",
     "sh", "-c",
     f"for auth in /data/*/authorized_clients/{client_name}.auth; do "
     f"  [ -f \"$auth\" ] && rm \"$auth\" && echo \"  Revoked: $auth\"; "
     f"done; "
     f"rm -rf /data/.clients/{client_name}"],
    check=True
)

print(f"Removed client: {client_name}")
print(f"\nRun 'd.rymcg.tech make tor reinstall' to apply changes.")
