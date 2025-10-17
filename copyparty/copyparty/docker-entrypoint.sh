#!/usr/bin/env bash
set -Eeuo pipefail

echo "## Entrypoint: /usr/local/bin/docker-entrypoint.sh"

CONFIG_PATH="${COPYPARTY_CONFIG:-/z/copyparty.conf}"

# ---- required admin ----
ADMIN_USER="${COPYPARTY_ADMIN_USER:?set COPYPARTY_ADMIN_USER}"
ADMIN_PASSWORD="${COPYPARTY_ADMIN_PASSWORD:?set COPYPARTY_ADMIN_PASSWORD}"

# ---- optional globals ----
PORT="${COPYPARTY_PORT:-3939}"
ALLOW_NET="${COPYPARTY_ALLOW_NET:-}"       # e.g. "10.89."
THEME="${COPYPARTY_THEME:-}"               # e.g. "2"
NAME="${COPYPARTY_NAME:-}"                 # e.g. "datasaver"
ENABLE_STATS="${COPYPARTY_ENABLE_STATS:-}" # "true" to add `stats`
DISABLE_DUPE="${COPYPARTY_DISABLE_DUPE:-}" # "true" to add `nos-dup`
ROBOTS_OFF="${COPYPARTY_NO_ROBOTS:-}"      # "true" to add `no-robots`
FORCE_JS="${COPYPARTY_FORCE_JS:-}"         # "true" to add `force-js`

DATA_ROOT="${COPYPARTY_DATA_DIR:-/data}"
ADMIN_PATH="${DATA_ROOT}/admin"
PUB_PATH="${COPYPARTY_VOL_PUBLIC_PATH:-${DATA_ROOT}/public}"
GST_PATH="${COPYPARTY_VOL_GUESTS_PATH:-${DATA_ROOT}/guests}"

mkdir -p "$(dirname "$CONFIG_PATH")" "$PUB_PATH" "$GST_PATH" /mnt

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
#   COPYPARTY_VOL_EXTERNAL    = "music:/storage/music,pics:/var/media/pics,photos:/mnt/photos"
#     - left side ("name") can include slashes; the section will be "[/<name>]"
#       and source becomes "/mnt/<name>" inside the container.
#   COPYPARTY_PERMISSIONS     = "/path:perm:user1/user2,..."
#     - example: "/data/ryan:rwmda:ryan,/data/music:rw:ryan/bob"
#     - "path" is the **virtual path** (section header), e.g., /mike or /photos
#     - users are slash-delimited to avoid commas
# ─────────────────────────────────────────────────────────────────────────────

# ---- parse users (accounts only) ----
USER_LINES=() # lines for [accounts]
IFS=',' read -ra _USR <<< "${COPYPARTY_USERS:-}"
for ent in "${_USR[@]}"; do
  [[ -z "$ent" ]] && continue
  u="${ent%%:*}"; p="${ent#*:}"
  if [[ -z "$u" || -z "$p" ]]; then
    echo "[entrypoint] ERROR: bad COPYPARTY_USERS item '$ent' (want user:pass)" >&2; echo "COPYPARTY_USERS=$COPYPARTY_USERS"; exit 1
  fi
  if [[ "$u$p" == *[,:\ ]* ]]; then
    echo "[entrypoint] ERROR: usernames/passwords cannot contain commas/colons/spaces: '$ent'" >&2; exit 1
  fi
  USER_LINES+=("  ${u}: ${p}")
done

# ---- parse external volumes (name -> host_path) ----
# name may contain slashes to allow mounting at nested virtual paths
declare -A VOL_PATHS=()  # virtual name => /mnt/<name> (container FS path)
declare -A VOL_HOST=()   # virtual name => original host path (for logging/help)
IFS=',' read -ra _VEX <<< "${COPYPARTY_VOL_EXTERNAL:-}"
for ent in "${_VEX[@]}"; do
  [[ -z "$ent" ]] && continue
  name="${ent%%:*}"; hpath="${ent#*:}"
  if [[ -z "$name" || -z "$hpath" ]]; then
    echo "[entrypoint] ERROR: bad COPYPARTY_VOL_EXTERNAL item '$ent' (want name:/abs/host/path)" >&2; exit 1
  fi
  if [[ "$name" == *[,:\ ]* || "$hpath" == *[,:\ ]* ]]; then
    echo "[entrypoint] ERROR: names/paths cannot contain commas/colons/spaces: '$ent'" >&2; exit 1
  fi
  if [[ "${hpath:0:1}" != "/" ]]; then
    echo "[entrypoint] ERROR: host path must be absolute: '$hpath'" >&2; exit 1
  fi
  VOL_HOST["$name"]="$hpath"
  # create nested dir structure if name has slashes
  vdir="/mnt/${name}"
  mkdir -p "$vdir"
  VOL_PATHS["$name"]="$vdir"
done

# ---- parse generic permissions (path:perm:users) ----
# PERM_MAP["/virtual/path|perm"]="user1 user2 ..."
declare -A PERM_MAP=()
declare -A PATH_SEEN=()   # record all paths mentioned in PERMISSIONS
IFS=',' read -ra _PERM <<< "${COPYPARTY_PERMISSIONS:-}"
for ent in "${_PERM[@]}"; do
  [[ -z "$ent" ]] && continue
  pth="${ent%%:*}"; rest="${ent#*:}"
  prm="${rest%%:*}"; userspec="${rest#*:}"

  if [[ -z "$pth" || -z "$prm" || -z "$userspec" ]]; then
    echo "[entrypoint] ERROR: bad COPYPARTY_PERMISSIONS item '$ent' (want /path:perm:user1/..)" >&2; exit 1
  fi
  if [[ "${pth:0:1}" != "/" ]]; then
    echo "[entrypoint] ERROR: permission path must be a virtual path starting with '/': '$pth'" >&2; exit 1
  fi
  # Validate perm only contains allowed letters (subset is fine)
  if [[ ! "$prm" =~ ^[rwmdgGhaA\.]+$ ]]; then
    echo "[entrypoint] ERROR: invalid permission letters '$prm' in '$ent'" >&2; exit 1
  fi

  IFS='/' read -ra _USERS <<< "$userspec"
  for user in "${_USERS[@]}"; do
    [[ -z "$user" ]] && continue
    if [[ "$user" == *[,:\ ]* ]]; then
      echo "[entrypoint] ERROR: usernames in permissions cannot contain commas/colons/spaces: '$user' in '$ent'" >&2; exit 1
    fi
    key="${pth}|${prm}"
    cur="${PERM_MAP[$key]:-}"
    if [[ " $cur " != *" $user "* ]]; then
      PERM_MAP[$key]="${cur:+$cur }$user"
    fi
  done
  PATH_SEEN["$pth"]=1
done

# ---- parse internal volumes (name -> $DATA_ROOT/name) ----
# COPYPARTY_VOL_INTERNAL="mike,team/docs,foo"
declare -A VOL_INT=()  # name => $DATA_ROOT/name
IFS=',' read -ra _VIN <<< "${COPYPARTY_VOL_INTERNAL:-}"
for name in "${_VIN[@]}"; do
  [[ -z "$name" ]] && continue
  if [[ "$name" == *[,:\ ]* ]]; then
    echo "[entrypoint] ERROR: internal volume names cannot contain commas/colons/spaces: '$name'" >&2
    exit 1
  fi
  src="${DATA_ROOT%/}/${name}"
  mkdir -p "$src"
  VOL_INT["$name"]="$src"
done

# ---- build the set of sections we will emit ----
# Built-ins (conditionally for public/guests, always admin), plus externals + internals.
declare -A SECTIONS=()   # virtual path -> container FS path

# admin (always present)
SECTIONS["/admin"]="$ADMIN_PATH"

# built-ins (optional)
if [[ "${COPYPARTY_ENABLE_PUBLIC_ACCESS}" == "true" ]]; then
  SECTIONS["/public"]="$PUB_PATH"
fi
if [[ "${COPYPARTY_ENABLE_GUEST_ACCESS}" == "true" ]]; then
  SECTIONS["/guests"]="$GST_PATH"
fi

# externals: expose them at "/<name>" -> "/mnt/<name>"
for name in "${!VOL_PATHS[@]}"; do
  vpath="/${name}"
  if [[ -n "${SECTIONS[$vpath]:-}" ]]; then
    echo "[entrypoint] ERROR: duplicate mount for '$vpath' (already defined as built-in or internal)" >&2
    exit 1
  fi
  SECTIONS["$vpath"]="${VOL_PATHS[$name]}"
done

# internals: expose at "/<name>" -> "$DATA_ROOT/<name>"
for name in "${!VOL_INT[@]}"; do
  vpath="/${name}"
  if [[ -n "${SECTIONS[$vpath]:-}" ]]; then
    echo "[entrypoint] ERROR: duplicate mount for '$vpath' (already defined as built-in or external)" >&2
    exit 1
  fi
  SECTIONS["$vpath"]="${VOL_INT[$name]}"
done

# sanity-check: every path referenced in PERMISSIONS must have a section
for pth in "${!PATH_SEEN[@]}"; do
  if [[ -z "${SECTIONS[$pth]:-}" ]]; then
    echo "[entrypoint] ERROR: COPYPARTY_PERMISSIONS references '$pth' but no matching mount is defined." >&2
    echo "  Define it via built-ins (/public, /guests, /admin), COPYPARTY_VOL_EXTERNAL, or COPYPARTY_VOL_INTERNAL." >&2
    exit 1
  fi
done

# deterministic order for stable config (nice for diffs/logging)
# sort keys into an array
mapfile -t SECTION_KEYS < <(printf "%s\n" "${!SECTIONS[@]}" | sort)

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

  # Emit sections
  for vpath in "${SECTION_KEYS[@]}"; do
    src="${SECTIONS[$vpath]}"
    echo "[${vpath}]"
    echo "  ${src}"
    echo "  accs:"

    # default perms for built-ins if desired (can still be overridden/extended)
    case "$vpath" in
      "/public")
        # If public is enabled but user didn't specify perms, default to r:* + admin full
        if ! printf "%s\n" "${!PERM_MAP[@]}" | grep -q "^${vpath}\|"; then
          echo "    r: *"
        fi
        ;;
      "/guests")
        if ! printf "%s\n" "${!PERM_MAP[@]}" | grep -q "^${vpath}\|"; then
          echo "    w: *"
        fi
        ;;
    esac

    # collect keys for this vpath and sort for stable output
    _keys_for_pth=()
    for key in "${!PERM_MAP[@]}"; do
        [[ "${key%%|*}" == "$vpath" ]] && _keys_for_pth+=("$key")
    done
    IFS=$'\n' read -r -d '' -a _keys_for_pth_sorted < <(printf "%s\n" "${_keys_for_pth[@]}" | sort && printf '\0')

    for key in "${_keys_for_pth_sorted[@]}"; do
        prm="${key#*|}"
        users="${PERM_MAP[$key]}"
        echo "    ${prm}: ${users// /,}"
    done

    # admin blanket
    echo "    rwmda: ${ADMIN_USER}"
    echo
  done

} > "$CONFIG_PATH"

echo "## Config: ${CONFIG_PATH}"
nl -ba "$CONFIG_PATH"
echo "## End config"
echo
echo "## Entrypoint handing off to copyparty now ..."
sync
set -x
exec python3 -m copyparty -c "$CONFIG_PATH" "$@"
