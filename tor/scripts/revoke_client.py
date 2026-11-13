#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""Revoke a client's access to a hidden service.

Usage:
  ./revoke_client.py PROJECT_NAME SERVICE_NAME CLIENT_NAME
"""
import sys, subprocess, re

project_name = sys.argv[1]
service_name = sys.argv[2]
client_name = sys.argv[3]
volume = f"{project_name}_tor_data"

for name, label in [(service_name, "service"), (client_name, "client")]:
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', name):
        print(f"Error: invalid {label} name '{name}'")
        sys.exit(1)

auth_path = f"/data/{service_name}/authorized_clients/{client_name}.auth"

# Check if auth file exists
result = subprocess.run(
    ["docker", "run", "--rm", "-v", f"{volume}:/data:ro", "alpine",
     "test", "-f", auth_path],
    capture_output=True
)
if result.returncode != 0:
    print(f"Error: client '{client_name}' is not authorized for service '{service_name}'.")
    sys.exit(1)

# Remove auth file
subprocess.run(
    ["docker", "run", "--rm", "-v", f"{volume}:/data", "alpine",
     "rm", auth_path],
    check=True
)

print(f"Revoked client '{client_name}' from service '{service_name}'.")
print(f"\nRun 'd.rymcg.tech make tor reinstall' to apply changes.")
