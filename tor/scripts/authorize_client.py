#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""Grant a client access to a hidden service.

Usage:
  ./authorize_client.py PROJECT_NAME SERVICE_NAME CLIENT_NAME
"""
import sys, subprocess, re

project_name = sys.argv[1]
service_name = sys.argv[2]
client_name = sys.argv[3]
volume = f"{project_name}_tor_data"

for name, label in [(service_name, "service"), (client_name, "client")]:
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', name):
        print(f"Error: invalid {label} name '{name}' (use only letters, digits, hyphens, underscores)")
        sys.exit(1)

# Read client public key
result = subprocess.run(
    ["docker", "run", "--rm", "-v", f"{volume}:/data:ro", "alpine",
     "cat", f"/data/.clients/{client_name}/public"],
    capture_output=True, text=True
)
if result.returncode != 0:
    print(f"Error: client '{client_name}' not found. Run 'make tor add-client client={client_name}' first.")
    sys.exit(1)
public_key = result.stdout.strip()

# Verify service directory exists
result = subprocess.run(
    ["docker", "run", "--rm", "-v", f"{volume}:/data:ro", "alpine",
     "test", "-d", f"/data/{service_name}"],
    capture_output=True
)
if result.returncode != 0:
    print(f"Error: service '{service_name}' not found in volume. Install tor first so the service directory is created.")
    sys.exit(1)

# Write auth file
auth_line = f"descriptor:x25519:{public_key}"
subprocess.run(
    ["docker", "run", "--rm", "-v", f"{volume}:/data", "alpine",
     "sh", "-c",
     f"mkdir -p /data/{service_name}/authorized_clients && "
     f"printf '%s\\n' '{auth_line}' > /data/{service_name}/authorized_clients/{client_name}.auth && "
     f"chown -R 100:100 /data/{service_name}/authorized_clients && "
     f"chmod 700 /data/{service_name}/authorized_clients && "
     f"chmod 600 /data/{service_name}/authorized_clients/{client_name}.auth"],
    check=True
)

print(f"Authorized client '{client_name}' for service '{service_name}'.")
print(f"\nRun 'd.rymcg.tech make tor reinstall' to apply changes.")
