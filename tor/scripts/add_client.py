#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["cryptography"]
# ///
"""Create a client keypair for Tor v3 client authorization.

Usage:
  ./add_client.py PROJECT_NAME CLIENT_NAME
"""
import sys, subprocess, base64, re

project_name = sys.argv[1]
client_name = sys.argv[2]
volume = f"{project_name}_tor_data"

if not re.fullmatch(r'[a-zA-Z0-9_-]+', client_name):
    print(f"Error: invalid client name '{client_name}' (use only letters, digits, hyphens, underscores)")
    sys.exit(1)

# Check if client already exists
result = subprocess.run(
    ["docker", "run", "--rm", "-v", f"{volume}:/data:ro", "alpine",
     "test", "-d", f"/data/.clients/{client_name}"],
    capture_output=True
)
if result.returncode == 0:
    print(f"Error: client '{client_name}' already exists.")
    sys.exit(1)

# Generate x25519 keypair
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat, PrivateFormat, NoEncryption

private_key = X25519PrivateKey.generate()
private_bytes = private_key.private_bytes(Encoding.Raw, PrivateFormat.Raw, NoEncryption())
public_bytes = private_key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)

private_b32 = base64.b32encode(private_bytes).decode().rstrip("=")
public_b32 = base64.b32encode(public_bytes).decode().rstrip("=")

# Store keys in volume
subprocess.run(
    ["docker", "run", "--rm", "-v", f"{volume}:/data", "alpine",
     "sh", "-c",
     f"mkdir -p /data/.clients/{client_name} && "
     f"printf '%s' '{public_b32}' > /data/.clients/{client_name}/public && "
     f"printf '%s' '{private_b32}' > /data/.clients/{client_name}/private && "
     f"chown -R 100:100 /data/.clients/{client_name} && "
     f"chmod 700 /data/.clients/{client_name} && "
     f"chmod 600 /data/.clients/{client_name}/public /data/.clients/{client_name}/private"],
    check=True
)

print(f"Created client: {client_name}")
