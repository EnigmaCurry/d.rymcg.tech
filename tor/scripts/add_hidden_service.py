#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""Add a hidden service entry to TOR_HIDDEN_SERVICES in the env file.

Usage:
  ./add_hidden_service.py ENV_FILE NAME [TOR:LOCAL] [PREFIX] [PROJECT_NAME]

If PREFIX is provided, generates a vanity .onion address using mkp224o.
"""
import sys, json, subprocess, re

env_file = sys.argv[1]
name = sys.argv[2]
port = sys.argv[3] if len(sys.argv) > 3 else ""
prefix = sys.argv[4] if len(sys.argv) > 4 else ""
project_name = sys.argv[5] if len(sys.argv) > 5 else ""

if port:
    tor_port, local_port = port.split(":")
    new_entry = [name, int(tor_port), int(local_port)]
else:
    new_entry = name

def svc_name(s):
    return s if isinstance(s, str) else s[0]

# Generate vanity address if prefix requested
if prefix:
    if not project_name:
        print("Error: PROJECT_NAME required for vanity address generation.")
        sys.exit(1)

    prefix = prefix.lower()
    if not re.fullmatch(r'[a-z2-7]+', prefix):
        print(f"Error: prefix '{prefix}' contains invalid characters.")
        print("Onion addresses use base32 encoding: only a-z and 2-7 are allowed.")
        sys.exit(1)

    volume = f"{project_name}_tor_data"

    def estimate_time(prefix_len, rate):
        """Estimate average time for a prefix length at a given keys/sec rate."""
        expected = 32 ** prefix_len
        seconds = expected / rate
        if seconds < 1:
            return "instant"
        elif seconds < 60:
            return f"~{int(seconds)} seconds"
        elif seconds < 3600:
            return f"~{int(seconds / 60)} minutes"
        elif seconds < 86400:
            return f"~{seconds / 3600:.1f} hours"
        elif seconds < 86400 * 365:
            return f"~{seconds / 86400:.0f} days"
        else:
            return f"~{seconds / (86400 * 365):.0f} years"

    # Build mkp224o image if not present
    result = subprocess.run(
        ["docker", "image", "inspect", "mkp224o"],
        capture_output=True
    )
    if result.returncode != 0:
        print("Building mkp224o image (first time only)...")
        dockerfile = """\
FROM alpine:3 AS build
RUN apk add --no-cache gcc make musl-dev libsodium-dev autoconf git
RUN git clone https://github.com/cathugger/mkp224o.git /build
WORKDIR /build
RUN ./autogen.sh && ./configure && make

FROM alpine:3
RUN apk add --no-cache libsodium
COPY --from=build /build/mkp224o /usr/local/bin/
ENTRYPOINT ["mkp224o"]
"""
        result = subprocess.run(
            ["docker", "build", "-t", "mkp224o", "-"],
            input=dockerfile, text=True, capture_output=True
        )
        if result.returncode != 0:
            print(result.stderr)
            print("Error: failed to build mkp224o image.")
            sys.exit(1)

    # Quick benchmark to estimate time
    if len(prefix) > 4:
        bench = subprocess.run(
            ["timeout", "3", "docker", "run", "--rm", "mkp224o",
             "-s", "zzzzzzzzzzzzzzzz"],
            capture_output=True, text=True
        )
        rate = 0
        for line in (bench.stdout + bench.stderr).splitlines():
            m = re.search(r'calc/sec:([\d.]+)', line)
            if m:
                rate = float(m.group(1))
        if rate > 0:
            est = estimate_time(len(prefix), rate)
            print(f"Generating {len(prefix)}-character vanity prefix '{prefix}' "
                  f"at {rate/1e6:.0f}M keys/sec (estimated: {est})")
        else:
            print(f"Generating {len(prefix)}-character vanity prefix '{prefix}'...")
        print("Please wait...")
    else:
        print(f"Generating vanity prefix '{prefix}'...")

    # Clean up any previous vanity-tmp
    subprocess.run(
        ["docker", "run", "--rm", "-v", f"{volume}:/data", "alpine",
         "rm", "-rf", "/data/.vanity-tmp"],
        capture_output=True
    )

    # Generate vanity address (let output show for progress)
    subprocess.run(
        ["docker", "run", "--rm", "-v", f"{volume}:/data", "mkp224o",
         "-n", "1", "-S", "1", "-d", "/data/.vanity-tmp", prefix],
        check=True
    )

    # Move generated keys to service directory
    subprocess.run(
        ["docker", "run", "--rm", "-v", f"{volume}:/data", "alpine",
         "sh", "-c",
         f"dir=$(ls -d /data/.vanity-tmp/*/); "
         f"mkdir -p /data/{name}; "
         f"cp -a \"$dir\"/* /data/{name}/; "
         f"chown -R 100:100 /data/{name}; "
         f"chmod 700 /data/{name}; "
         f"rm -rf /data/.vanity-tmp"],
        check=True
    )

    # Read and display the generated hostname
    result = subprocess.run(
        ["docker", "run", "--rm", "-v", f"{volume}:/data:ro", "alpine",
         "cat", f"/data/{name}/hostname"],
        capture_output=True, text=True, check=True
    )
    print(f"Generated vanity address: {result.stdout.strip()}")

# Update env file
with open(env_file) as f:
    lines = f.read().splitlines()

for i, line in enumerate(lines):
    if line.startswith("TOR_HIDDEN_SERVICES="):
        current = json.loads(line.split("=", 1)[1])
        filtered = [s for s in current if svc_name(s) != name]
        replaced = len(filtered) < len(current)
        filtered.append(new_entry)
        lines[i] = "TOR_HIDDEN_SERVICES=" + json.dumps(filtered)
        break

with open(env_file, "w") as f:
    f.write("\n".join(lines) + "\n")

action = "Replaced" if replaced else "Added"
if isinstance(new_entry, str):
    print(f"{action} HTTP hidden service: {name}")
else:
    print(f"{action} TCP hidden service: {name} (.onion:{new_entry[1]} -> localhost:{new_entry[2]})")

print(f"\nRun 'd.rymcg.tech make tor reinstall' to apply changes.")
