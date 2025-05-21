#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"
ENV_DIST_FILE=".env-dist"

if [ ! -f "${ENV_DIST_FILE}" ]; then
  echo "[ERROR] ${ENV_DIST_FILE} not found!"
  exit 1
fi

cp "${ENV_DIST_FILE}" "${ENV_FILE}"
echo "[INFO] Copied ${ENV_DIST_FILE} to ${ENV_FILE}"
echo "[INFO] Configuring environment variables..."
echo

# Read variables and associated comments
VARS=()
declare -A VAR_COMMENTS
CURRENT_COMMENT=""

while IFS= read -r line || [ -n "$line" ]; do
  if [[ "$line" =~ ^# ]]; then
    # Collect comment lines
    CURRENT_COMMENT+="${line}"$'\n'
  elif [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
    var_name="${line%%=*}"
    VARS+=("$var_name")
    if [ -n "$CURRENT_COMMENT" ]; then
      # Strip final newline when saving
      VAR_COMMENTS["$var_name"]="$(echo -n "$CURRENT_COMMENT")"
      CURRENT_COMMENT=""
    fi
  else
    CURRENT_COMMENT=""
  fi
done < "${ENV_DIST_FILE}"

# Read existing .env values if .env already exists
declare -A EXISTING_VARS
if [ -f "${ENV_FILE}" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      var_name="${line%%=*}"
      var_value="${line#*=}"
      EXISTING_VARS["$var_name"]="$var_value"
    fi
  done < "${ENV_FILE}"
fi

# Prompt for each variable
for VAR in "${VARS[@]}"; do
  # Print comment right above prompt, NO extra newline
  if [ -n "${VAR_COMMENTS[$VAR]+x}" ]; then
    echo -n "${VAR_COMMENTS[$VAR]}"
    echo  # manual linebreak after comment (only one)
  fi

  default="${EXISTING_VARS[$VAR]:-}"

  prompt="${VAR}"
  if [ -n "$default" ]; then
    prompt+=" [${default}]"
  fi
  prompt+=": "

  VALUE=""
  while [ -z "$VALUE" ]; do
    read -rp "$prompt" input
    if [ -z "$input" ]; then
      if [ -n "$default" ]; then
        VALUE="$default"
      else
        echo "[WARN] ${VAR} cannot be blank. Please enter a value."
      fi
    else
      VALUE="$input"
    fi
  done

  echo  # Blank line AFTER input for breathing room

  # Update the .env file
  sed -i.bak "s|^${VAR}=.*|${VAR}=${VALUE}|" "${ENV_FILE}"
done

rm -f "${ENV_FILE}.bak"

echo "[SUCCESS] Configuration complete. Your .env file is ready."
