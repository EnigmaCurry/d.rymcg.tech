#!/usr/bin/env bash
set -Eeuo pipefail

: "${BIN:?Need to set BIN}"
: "${ENV_FILE:?Need to set ENV_FILE}"

# Shortcuts
WZ="${BIN}/wizard"

# Fetch current values (empty if missing)
CURRENT_VEX="$("${BIN}/dotenv" -f "${ENV_FILE}" get COPYPARTY_VOL_EXTERNAL 2>/dev/null || true)"
CURRENT_VEX="${CURRENT_VEX## }"; CURRENT_VEX="${CURRENT_VEX%% }"

CURRENT_PERM="$("${BIN}/dotenv" -f "${ENV_FILE}" get COPYPARTY_PERMISSIONS 2>/dev/null || true)"
CURRENT_PERM="${CURRENT_PERM## }"; CURRENT_PERM="${CURRENT_PERM%% }"

# Migrate the deprecated COPYPARTY_VOL_PERMISSIONS (name:perm:users) to
# COPYPARTY_PERMISSIONS (/path:perm:users):
OLD_PERM="$("${BIN}/dotenv" -f "${ENV_FILE}" get COPYPARTY_VOL_PERMISSIONS 2>/dev/null || true)"
OLD_PERM="${OLD_PERM## }"; OLD_PERM="${OLD_PERM%% }"
if [[ -n "${OLD_PERM}" ]]; then
  if [[ -z "${CURRENT_PERM}" ]]; then
    declare -a _migrated=()
    IFS=',' read -r -a _old <<< "${OLD_PERM}"
    for ent in "${_old[@]}"; do [[ -n "$ent" ]] && _migrated+=("/${ent#/}"); done
    CURRENT_PERM="$(IFS=','; echo "${_migrated[*]}")"
    echo "Migrated deprecated COPYPARTY_VOL_PERMISSIONS to COPYPARTY_PERMISSIONS: ${CURRENT_PERM}"
  else
    echo "Removing deprecated COPYPARTY_VOL_PERMISSIONS (COPYPARTY_PERMISSIONS is already set)."
  fi
fi

# Arrays to collect entries
declare -a VOL_ENTRIES=()
declare -a PERM_ENTRIES=()

# Seed from existing values
if [[ -n "${CURRENT_VEX}" ]]; then
  IFS=',' read -r -a _seed_vex <<< "${CURRENT_VEX}"
  for ent in "${_seed_vex[@]}"; do [[ -n "$ent" ]] && VOL_ENTRIES+=("${ent}"); done
fi
if [[ -n "${CURRENT_PERM}" ]]; then
  IFS=',' read -r -a _seed_perm <<< "${CURRENT_PERM}"
  for ent in "${_seed_perm[@]}"; do [[ -n "$ent" ]] && PERM_ENTRIES+=("${ent}"); done
fi

echo "Existing COPYPARTY_VOL_EXTERNAL: ${CURRENT_VEX:-<none>}"
if ((${#VOL_ENTRIES[@]})); then
  if ! "${WZ}" confirm "Keep existing volume entries?" yes; then
    VOL_ENTRIES=()
  fi
fi

echo "Existing COPYPARTY_PERMISSIONS: ${CURRENT_PERM:-<none>}"
if ((${#PERM_ENTRIES[@]})); then
  if ! "${WZ}" confirm "Keep existing permission entries?" yes; then
    PERM_ENTRIES=()
  fi
fi

# ── Add/modify volumes ────────────────────────────────────────────────────────
if "${WZ}" confirm "Do you want to add external volumes now?" no; then
  echo "Enter volumes as a name and an absolute host path."
  echo "  - name: letters, numbers, dot, dash, underscore (e.g. music, pics-1)"
  echo "  - path: absolute host path like /srv/music"
  while :; do
    echo
    name="$("${WZ}" ask "Volume name")"
    [[ -z "${name}" ]] && break
    if [[ ! "${name}" =~ ^[A-Za-z0-9._-]+$ ]]; then
      echo "  [!] Invalid name. Allowed: letters, numbers, ., _, -"
      continue
    fi

    host="$("${WZ}" ask "Absolute host path for '${name}' (e.g. /storage/${name})")"
    if [[ -z "${host}" ]]; then
      echo "  [!] Empty path; try again."
      continue
    fi
    if [[ "${host:0:1}" != "/" ]]; then
      echo "  [!] Path must be absolute (start with '/')."
      continue
    fi
    if [[ "${host}" == *[,:\ ]* ]]; then
      echo "  [!] Path cannot contain commas, colons, or spaces."
      continue
    fi

    VOL_ENTRIES+=("${name}:${host}")
    echo "  [+] Added volume ${name}:${host}"

    if ! "${WZ}" confirm "Add another volume?" yes; then
      break
    fi
  done
fi

# Build a list of known volume names (from VOL_ENTRIES) for user convenience
declare -a KNOWN_VOL_NAMES=()
for v in "${VOL_ENTRIES[@]}"; do
  vname="${v%%:*}"
  KNOWN_VOL_NAMES+=("${vname}")
done

# ── Add/modify permissions ────────────────────────────────────────────────────
if "${WZ}" confirm "Do you want to add path permissions now?" no; then
  echo "Add permission entries in the form: /path:perm:users"
  echo "  - path: a copyparty URL path, e.g. /team-docs or /music/live"
  echo "    A path under an external volume (${KNOWN_VOL_NAMES[*]:-<none yet>}) is stored on that volume;"
  echo "    any other path is stored on the copyparty data volume."
  echo "  - perm: combination of letters from [rwmdgGhaA.] (e.g. r, rw, rwmda)"
  echo "  - users: list of usernames separated by '/' (slashes), e.g. ryan/bob"
  echo "    (Tip: You can enter commas/spaces; they will be converted to '/')"
  echo "  Each path is its own copyparty volume: permissions are NOT inherited"
  echo "  from a parent path, so give every path its full list of users."

  while :; do
    echo
    path="$("${WZ}" ask "Path for permissions (e.g. /team-docs)")"
    [[ -z "${path}" ]] && break
    [[ "${path}" == /* ]] || path="/${path}"
    while [[ "${path}" != "/" && "${path}" == */ ]]; do path="${path%/}"; done
    if [[ ! "${path}" =~ ^(/[A-Za-z0-9_-][A-Za-z0-9._-]*)+$ ]]; then
      echo "  [!] Invalid path. Use letters, numbers, ., _, - and /; no empty or dot-prefixed segments."
      continue
    fi
    first="${path#/}"; first="${first%%/*}"
    case "${first}" in
      admin|public|guests|home|share)
        echo "  [!] /${first} is reserved for copyparty's built-in volumes."
        continue ;;
    esac

    perm="$("${WZ}" ask "Permission letters for '${path}' (e.g. r, rw, rwmda)")"
    if [[ -z "${perm}" || ! "${perm}" =~ ^[rwmdgGhaA\.]+$ ]]; then
      echo "  [!] Invalid permission string. Use only letters in [rwmdgGhaA.]"
      continue
    fi

    raw_users="$("${WZ}" ask "Users for '${path}' (separate with '/', ',' or spaces)")"
    if [[ -z "${raw_users}" ]]; then
      echo "  [!] Empty user list; try again."
      continue
    fi
    # Normalize delimiters to slash; strip leading/trailing slashes
    users="$(printf '%s' "${raw_users}" | tr ' ,\t' '///' | tr -s '/' '/' )"
    users="${users#/}"; users="${users%/}"

    # Validate users (no commas/colons/spaces after normalization)
    if [[ -z "${users}" || "${users}" == *[:,\ ]* ]]; then
      echo "  [!] Invalid user list formatting."
      continue
    fi

    PERM_ENTRIES+=("${path}:${perm}:${users}")
    echo "  [+] Added permission ${path}:${perm}:${users}"

    if ! "${WZ}" confirm "Add another permission entry?" no; then
      break
    fi
  done
fi

# ── Write back to .env ────────────────────────────────────────────────────────
IFS=','; "${BIN}/reconfigure" "${ENV_FILE}" "COPYPARTY_VOL_EXTERNAL=${VOL_ENTRIES[*]:-}"
IFS=','; "${BIN}/reconfigure" "${ENV_FILE}" "COPYPARTY_PERMISSIONS=${PERM_ENTRIES[*]:-}"
if [[ -n "${OLD_PERM}" ]]; then
  "${BIN}/reconfigure" "${ENV_FILE}" "COPYPARTY_VOL_PERMISSIONS="
fi

echo "Updated:"
echo "  COPYPARTY_VOL_EXTERNAL=${VOL_ENTRIES[*]:-}"
echo "  COPYPARTY_PERMISSIONS=${PERM_ENTRIES[*]:-}"
