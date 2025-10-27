#!/usr/bin/env bash
set -Eeuo pipefail

echo "## Entrypoint: /usr/local/bin/docker-entrypoint.sh"

# ---- required admin ----
ADMIN_USER="${COPYPARTY_ADMIN_USER:?set COPYPARTY_ADMIN_USER}"
ADMIN_PASSWORD="${COPYPARTY_ADMIN_PASSWORD:?set COPYPARTY_ADMIN_PASSWORD}"

# ---- optional globals ----
PORT="${COPYPARTY_PORT:-3923}"
ALLOW_NET="${COPYPARTY_ALLOW_NET:-}"       # e.g. "10.89."
THEME="${COPYPARTY_THEME:-}"               # e.g. "2"
NAME="${COPYPARTY_NAME:-}"                 # e.g. "datasaver"
ENABLE_STATS="${COPYPARTY_ENABLE_STATS:-}" # "true" to add `stats`
DISABLE_DUPE="${COPYPARTY_DISABLE_DUPE:-}" # "true" to add `nos-dup`
ROBOTS_OFF="${COPYPARTY_NO_ROBOTS:-}"      # "true" to add `no-robots`
FORCE_JS="${COPYPARTY_FORCE_JS:-}"         # "true" to add `force-js`

DATA_ROOT="${COPYPARTY_DATA_DIR:-/data}"
CONFIG_PATH="${COPYPARTY_CONFIG:-${DATA_ROOT}/config/copyparty.conf}"
MNT_ROOT="${COPYPARTY_MNT_ROOT:-${DATA_ROOT}/mnt}"

ADMIN_PATH="${DATA_ROOT}/admin"
PUB_PATH="${COPYPARTY_VOL_PUBLIC_PATH:-${DATA_ROOT}/public}"
GST_PATH="${COPYPARTY_VOL_GUESTS_PATH:-${DATA_ROOT}/guests}"

# Make sure our user-writable trees exist
umask 022
mkdir -p "$(dirname "$CONFIG_PATH")" "$PUB_PATH" "$GST_PATH" "$MNT_ROOT"

# ---- build optional [global] flags ----
optflags=()
[[ -n "$ALLOW_NET" ]] && optflags+=("ipa: ${ALLOW_NET}")
[[ -n "$THEME"     ]] && optflags+=("theme: ${THEME}")
[[ -n "$NAME"      ]] && optflags+=("name: ${NAME}")
[[ "${ENABLE_STATS,,}" == "true" ]] && optflags+=("stats")
[[ "${DISABLE_DUPE,,}" == "true" ]] && optflags+=("nos-dup")
[[ "${ROBOTS_OFF,,}"   == "true" ]] && optflags+=("no-robots")
[[ "${FORCE_JS,,}"     == "true" ]] && optflags+=("force-js")

# ─────────────────────────────────────────────────────────────────────────────
# INPUT SHAPES
#   COPYPARTY_USERS           = "user:pass,alice:pw2"
#   COPYPARTY_VOL_EXTERNAL    = "music:/storage/music,pics:/var/media/pics"
#   COPYPARTY_VOL_PERMISSIONS = "music:rw:ryan/bob,pics:rwmda:admin,music:r:erin"
#
# NOTE: user lists in VOL_PERMISSIONS are slash-delimited to avoid commas.
# NOTE: If you bind-mount host dirs for external vols, mount them to $MNT_ROOT/<name>.
# ─────────────────────────────────────────────────────────────────────────────

# ---- parse users (accounts only) ----
USER_LINES=() # lines for [accounts]
IFS=',' read -ra _USR <<< "${COPYPARTY_USERS:-}"
for ent in "${_USR[@]}"; do
  [[ -z "$ent" ]] && continue
  u="${ent%%:*}"; p="${ent#*:}"
  if [[ -z "$u" || -z "$p" ]]; then
    echo "[entrypoint] ERROR: bad COPYPARTY_USERS item '$ent' (want user:pass)" >&2
    echo "COPYPARTY_USERS=${COPYPARTY_USERS:-}" >&2
    exit 1
  fi
  if [[ "$u$p" == *[,:\ ]* ]]; then
    echo "[entrypoint] ERROR: usernames/passwords cannot contain commas/colons/spaces: '$ent'" >&2
    exit 1
  fi
  USER_LINES+=("  ${u}: ${p}")
done

# ---- parse external volumes (name -> container path) ----
declare -A VOL_PATHS=()  # name => ${MNT_ROOT}/<name>
declare -A VOL_HOST=()   # name => given host path (for logs)
IFS=',' read -ra _VEX <<< "${COPYPARTY_VOL_EXTERNAL:-}"
for ent in "${_VEX[@]}"; do
  [[ -z "$ent" ]] && continue
  name="${ent%%:*}"; hpath="${ent#*:}"
  if [[ -z "$name" || -z "$hpath" ]]; then
    echo "[entrypoint] ERROR: bad COPYPARTY_VOL_EXTERNAL item '$ent' (want name:/abs/host/path)" >&2
    exit 1
  fi
  if [[ "$name" == *[,:\ ]* || "$hpath" == *[,:\ ]* ]]; then
    echo "[entrypoint] ERROR: names/paths cannot contain commas/colons/spaces: '$ent'" >&2
    exit 1
  fi
  if [[ "${hpath:0:1}" != "/" ]]; then
    echo "[entrypoint] ERROR: host path must be absolute: '$hpath'" >&2
    exit 1
  fi
  VOL_HOST["$name"]="$hpath"
  VOL_PATHS["$name"]="${MNT_ROOT}/${name}"
  mkdir -p "${VOL_PATHS["$name"]}"
done

# ---- parse per-volume permissions and merge ----
# map: VOL_PERM["<name>|<perm>"]="user1 user2 ..."
declare -A VOL_PERM=()
IFS=',' read -ra _VP <<< "${COPYPARTY_VOL_PERMISSIONS:-}"
for ent in "${_VP[@]}"; do
  [[ -z "$ent" ]] && continue
  # Expect: name:perm:user1/user2/...
  name="${ent%%:*}"; rest="${ent#*:}"
  perm="${rest%%:*}"; userspec="${rest#*:}"

  if [[ -z "$name" || -z "$perm" || -z "$userspec" ]]; then
    echo "[entrypoint] ERROR: bad COPYPARTY_VOL_PERMISSIONS item '$ent' (want name:perm:user1/..)" >&2
    exit 1
  fi
  # Validate perm letters (copyparty accepts r,w,m,d,a,g,G,h,A,.)
  if [[ ! "$perm" =~ ^[rwmdgGhaA\.]+$ ]]; then
    echo "[entrypoint] ERROR: invalid permission letters '$perm' in '$ent'" >&2
    exit 1
  fi

  IFS='/' read -ra _USERS <<< "$userspec"
  for user in "${_USERS[@]}"; do
    [[ -z "$user" ]] && continue
    if [[ "$user" == *[,:\ ]* ]]; then
      echo "[entrypoint] ERROR: usernames in permissions cannot contain commas/colons/spaces: '$user' in '$ent'" >&2
      exit 1
    fi
    key="${name}|${perm}"
    cur="${VOL_PERM[$key]:-}"
    if [[ " $cur " != *" $user "* ]]; then
      VOL_PERM[$key]="${cur:+$cur }$user"
    fi
  done
done

# ---- sanity checks for writable config dir ----
cfgdir="$(dirname "$CONFIG_PATH")"
if [[ ! -w "$cfgdir" ]]; then
  echo "[entrypoint] ERROR: config directory not writable by $(whoami): $cfgdir" >&2
  exit 1
fi

# ---- emit config file ----
{
  echo "# -*- pretend-yaml -*-"
  echo
  echo "[global]"
  echo "  e2dsa"
  echo "  e2ts"
  echo "  ansi"
  echo "  xff-src: lan"
  echo "  xff-hdr: X-Forwarded-For"
  echo "  shr: /share"
  echo "  shr-who: a"
  echo "  shr-adm: admin"
  echo "  p: ${PORT}"
  for f in "${optflags[@]}"; do echo "  ${f}"; done
  echo
  echo "[accounts]"
  echo "  ${ADMIN_USER}: ${ADMIN_PASSWORD}"
  if ((${#USER_LINES[@]})); then
    printf "%s\n" "${USER_LINES[@]}"
  fi
  echo
  echo
  # Require at least one volume; always create admin-only volume
  echo "[/admin]"
  echo "  ${ADMIN_PATH}"
  echo "  accs:"
  echo "    rwmda: ${ADMIN_USER}"
  echo

  # Built-ins: public (read-only everyone), guests (write-only everyone)
  if [[ "${COPYPARTY_ENABLE_PUBLIC_ACCESS}" == "true" ]]; then
      echo "[/public]"
      echo "  ${PUB_PATH}"
      echo "  accs:"
      echo "    r: *"
      echo "    rwmda: ${ADMIN_USER}"
      echo
  fi
  if [[ "${COPYPARTY_ENABLE_GUEST_ACCESS}" == "true" ]]; then
      echo "[/guests]"
      echo "  ${GST_PATH}"
      echo "  accs:"
      echo "    w: *"
      echo "    rwmda: ${ADMIN_USER}"
      echo
  fi

  # External volumes
  for name in "${!VOL_PATHS[@]}"; do
    vpath="/${name}"
    rpath="${VOL_PATHS[$name]}"
    echo "[${vpath}]"
    echo "  ${rpath}"
    echo "  accs:"
    # user-defined perms
    for key in "${!VOL_PERM[@]}"; do
      kvol="${key%%|*}"; kperm="${key#*|}"
      [[ "$kvol" != "$name" ]] && continue
      users="${VOL_PERM[$key]}"
      echo "    ${kperm}: ${users// /,}"
    done
    # always grant admin full perms
    echo "    rwmda: ${ADMIN_USER}"
    echo
  done
} > "$CONFIG_PATH"

echo "## Config: ${CONFIG_PATH}"
nl -ba "$CONFIG_PATH"
echo "## End config"
echo
echo "## Entrypoint handing off to copyparty now ..."
exec python3 -m copyparty -c "$CONFIG_PATH" "$@"
