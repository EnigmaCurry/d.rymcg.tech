#!/usr/bin/env bash
set -Eeuo pipefail

: "${BIN:?Need to set BIN}"
: "${ENV_FILE:?Need to set ENV_FILE}"

# Shortcuts
WZ="${BIN}/wizard"

# Fetch current values (empty if missing)
CURRENT_VEX="$("${BIN}/dotenv" -f "${ENV_FILE}" get COPYPARTY_VOL_EXTERNAL 2>/dev/null || true)"
CURRENT_VEX="${CURRENT_VEX## }"; CURRENT_VEX="${CURRENT_VEX%% }"

CURRENT_PERM="$("${BIN}/dotenv" -f "${ENV_FILE}" get COPYPARTY_VOL_PERMISSIONS 2>/dev/null || true)"
CURRENT_PERM="${CURRENT_PERM## }"; CURRENT_PERM="${CURRENT_PERM%% }"

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

echo "Existing COPYPARTY_VOL_PERMISSIONS: ${CURRENT_PERM:-<none>}"
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
if "${WZ}" confirm "Do you want to add volume permissions now?" no; then
  echo "Add permission entries in the form: name:perm:users"
  echo "  - name: a volume name (ideally one of: ${KNOWN_VOL_NAMES[*]:-<none yet>})"
  echo "  - perm: combination of letters from [rwmdgGhaA.] (e.g. r, rw, rwmda)"
  echo "  - users: list of usernames separated by '/' (slashes), e.g. ryan/bob"
  echo "    (Tip: You can enter commas/spaces; they will be converted to '/')"

  while :; do
    echo
    vname="$("${WZ}" ask "Volume name for permissions")"
    [[ -z "${vname}" ]] && break
    if [[ ! "${vname}" =~ ^[A-Za-z0-9._-]+$ ]]; then
      echo "  [!] Invalid volume name syntax."
      continue
    fi

    perm="$("${WZ}" ask "Permission letters for '${vname}' (e.g. r, rw, rwmda)")"
    if [[ -z "${perm}" || ! "${perm}" =~ ^[rwmdgGhaA\.]+$ ]]; then
      echo "  [!] Invalid permission string. Use only letters in [rwmdgGhaA.]"
      continue
    fi

    raw_users="$("${WZ}" ask "Users for '${vname}' (separate with '/', ',' or spaces)")"
    if [[ -z "${raw_users}" ]]; then
      echo "  [!] Empty user list; try again."
      continue
    fi
    # Normalize delimiters to slash; strip leading/trailing slashes
    users="$(printf '%s' "${raw_users}" | tr ' ,\t' '///' | tr -s '/' '/' )"
    users="${users#/}"; users="${users%/}"

    # Validate users (no commas/colons/spaces after normalization)
    if [[ "${users}" == *[:,\ ]* || "${users}" == *'//'*
      || "${users}" == /* || "${users}" == */ ]]; then
      echo "  [!] Invalid user list formatting."
      continue
    fi

    PERM_ENTRIES+=("${vname}:${perm}:${users}")
    echo "  [+] Added permission ${vname}:${perm}:${users}"

    if ! "${WZ}" confirm "Add another permission entry?" no; then
      break
    fi
  done
fi

# ── Write back to .env ────────────────────────────────────────────────────────
IFS=','; "${BIN}/reconfigure" "${ENV_FILE}" "COPYPARTY_VOL_EXTERNAL=${VOL_ENTRIES[*]:-}"
IFS=','; "${BIN}/reconfigure" "${ENV_FILE}" "COPYPARTY_VOL_PERMISSIONS=${PERM_ENTRIES[*]:-}"

echo "Updated:"
echo "  COPYPARTY_VOL_EXTERNAL=${VOL_ENTRIES[*]:-}"
echo "  COPYPARTY_VOL_PERMISSIONS=${PERM_ENTRIES[*]:-}"
