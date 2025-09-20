#!/usr/bin/env bash
set -Eeuo pipefail

echo "## Entrypoint: /usr/local/bin/docker-entrypoint.sh"

CONFIG_PATH="${COPYPARTY_CONFIG:-/z/copyparty.conf}"

# Tweakables via env (with sane defaults); override in compose if you want
optflags=()
PORT="${COPYPARTY_PORT:-3939}"
ALLOW_NET="${COPYPARTY_ALLOW_NET:-}"       # e.g. "10.89."
THEME="${COPYPARTY_THEME:-}"               # e.g. "2"
NAME="${COPYPARTY_NAME:-}"                 # e.g. "datasaver"
ENABLE_STATS="${COPYPARTY_ENABLE_STATS:-}" # "true" to add `stats`
DISABLE_DUPE="${COPYPARTY_DISABLE_DUPE:-}" # "true" to add `nos-dup`
ROBOTS_OFF="${COPYPARTY_NO_ROBOTS:-}"      # "true" to add `no-robots`
FORCE_JS="${COPYPARTY_FORCE_JS:-}"         # "true" to add `force-js`

# --- accounts + volume paths (fixed shared vols) ---
ADMIN_USER="${COPYPARTY_ADMIN_USER}"
ADMIN_PASSWORD="${COPYPARTY_ADMIN_PASSWORD}"

DATA_ROOT="${COPYPARTY_DATA_DIR:-/data}"
PUB_PATH="${COPYPARTY_VOL_PUBLIC_PATH:-${DATA_ROOT}/public}"
GST_PATH="${COPYPARTY_VOL_GUESTS_PATH:-${DATA_ROOT}/guests}"

mkdir -p "$(dirname "$CONFIG_PATH")" "$PUB_PATH" "$GST_PATH"

# Parse COPYPARTY_USERS: "mike:supersecret:/data/mike,bob:secret:/data/bob"
# For each user, create account and private volume "/<user>" -> path
USER_LINES=()     # [accounts] lines
USER_VOLS=()      # volume blocks

if [[ -z "$ADMIN_USER" || -z "$ADMIN_PASSWORD" ]]; then
    echo "[entrypoint] ERROR: ADMIN_USER and ADMIN_PASSWORD were not set." >&2
    exit 1
fi

IFS=',' read -ra __USR_ENTRIES <<< "${COPYPARTY_USERS:-}"
for ent in "${__USR_ENTRIES[@]}"; do
  [[ -z "$ent" ]] && continue
  u="${ent%%:*}"; rest="${ent#*:}"
  p="${rest%%:*}"; path="${rest#*:}"

  if [[ -z "$u" || -z "$p" || -z "$path" ]]; then
    echo "[entrypoint] ERROR: bad COPYPARTY_USERS item '$ent' (want user:pass:/abs/path), skipping" >&2
    exit 1
  fi

  if [[ "$u$p$path" == *[,:\ ]* ]]; then
      echo "[entrypoint] ERROR: user/pass/path may not contain commas/colons/spaces; failed entry: '$ent'" >&2
      exit 1
  fi

  if [[ "${path:0:1}" != "/" ]]; then
    echo "[entrypoint] ERROR: path '$path' is not absolute for user '$u', skipping" >&2
    exit 1
  fi

  mkdir -p "$path"
  USER_LINES+=("  ${u}: ${p}")
  USER_VOLS+=("
[/${u}]
  ${path}
  accs:
    rw: ${u}      # only this user can read+write; no 'ro: *' → others can't browse
")
done

{
  echo "# -*- pretend-yaml -*-"
  echo
  echo "[global]"
  echo "  e2dsa"
  echo "  e2ts"
  echo "  ansi"
  echo "  p: ${PORT}"
  for f in "${optflags[@]}"; do echo "  ${f}"; done
  echo
  echo "[accounts]"
  echo "  ${ADMIN_USER}: ${ADMIN_PASSWORD}"
  if ((${#USER_LINES[@]})); then
    printf "%s\n" "${USER_LINES[@]}"
  fi
  echo
  echo "[/public]"
  echo "  ${PUB_PATH}"
  echo "  accs:"
  echo "    r: *"
  echo "    rwmda: ${ADMIN_USER}"
  echo
  echo "[/guests]"
  echo "  ${GST_PATH}"
  echo "  accs:"
  echo "    w: *"
  echo "    rwmda: ${ADMIN_USER}"
  # per-user private volumes
  if ((${#USER_VOLS[@]})); then
    # Re-emit each user volume but inject admin rights
    while IFS= read -r -d '' blk; do
      # print the block as-is, then add admin
      printf "%s" "$blk"
      printf "  rwmda: %s\n" "${ADMIN_USER}"
      printf "\n"
    done < <(printf "%s\0" "${USER_VOLS[@]}")
  fi
} > "$CONFIG_PATH"

echo "## Config: ${CONFIG_PATH}"
cat ${CONFIG_PATH} | nl
echo "## End config"
echo
echo "## Entrypoint handing off to copyparty now ..."
cat "$CONFIG_PATH"
sync
set -x

# Hand off to the real process (PID 1 gets signals properly)
exec python3 -m copyparty -c "$CONFIG_PATH" "$@"
