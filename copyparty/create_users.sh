#!/usr/bin/env bash
set -Eeuo pipefail

: "${BIN:?Need to set BIN}"
: "${ENV_FILE:?Need to set ENV_FILE}"

DATA_ROOT="${COPYPARTY_DATA_DIR:-/data}"

# Load current value (if any)
CURRENT_CU="$("${BIN}/dotenv" -f "${ENV_FILE}" get COPYPARTY_USERS 2>/dev/null || true)"
CURRENT_CU="${CURRENT_CU## }"; CURRENT_CU="${CURRENT_CU%% }"

declare -a ENTRIES=()
if [[ -n "${CURRENT_CU}" ]]; then
  IFS=',' read -r -a _seed <<< "${CURRENT_CU}"
  for ent in "${_seed[@]}"; do
    [[ -z "${ent}" ]] && continue
    ENTRIES+=("${ent}")
  done
fi

echo "Existing COPYPARTY_USERS: ${CURRENT_CU:-<none>}"
if ((${#ENTRIES[@]})); then
  if ! ${BIN}/wizard confirm "Keep existing entries?" yes; then
    ENTRIES=()
  fi
fi

# Ask whether to add more users
if ! ${BIN}/wizard confirm "Do you want to add additional user accounts now?" no; then
  IFS=','; "${BIN}/reconfigure" "${ENV_FILE}" "COPYPARTY_USERS=${ENTRIES[*]:-}"
  exit 0
fi

# Helpers
forbid_chars_desc="(no commas ',', colons ':', or spaces)"
forbid_pat='*[,:\ ]*'

while :; do
  echo

  user="$(${BIN}/wizard ask "Username")"
  [[ -z "${user}" ]] && break

  if [[ "${user}" == ${forbid_pat} ]]; then
    echo "  [!] Username cannot contain commas, colons, or spaces; try again."
    continue
  fi

  # Password (enforce rule)
  while :; do
    pass="$(${BIN}/wizard ask "Password for '${user}'")"
    if [[ -z "${pass}" ]]; then
      echo "  [!] Empty password; skipping this entry."
      break
    fi
    if [[ "${pass}" == ${forbid_pat} ]]; then
      echo "  [!] Password cannot contain commas, colons, or spaces; try again."
      continue
    fi
    # got a valid password
    break
  done
  [[ -z "${pass}" ]] && continue

  def_path="${DATA_ROOT%/}/${user}"
  path="$(${BIN}/wizard ask "Absolute mount path for '${user}' [${def_path}]")"
  path="${path:-$def_path}"

  if [[ "${path:0:1}" != "/" ]]; then
    echo "  [!] Path must be absolute (start with '/'); try again."
    continue
  fi
  if [[ "${path}" == ${forbid_pat} ]]; then
    echo "  [!] Path cannot contain commas, colons, or spaces; try again."
    continue
  fi

  ENTRIES+=("${user}:${pass}:${path}")
  echo "  [+] Added ${user}:${path}"

  # Keep looping by default (nice for bulk entry)
  if ! ${BIN}/wizard confirm "Add another user?" no; then
    break
  fi
done

IFS=','; "${BIN}/reconfigure" "${ENV_FILE}" "COPYPARTY_USERS=${ENTRIES[*]:-}"
