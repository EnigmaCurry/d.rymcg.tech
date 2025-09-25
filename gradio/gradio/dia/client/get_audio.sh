#!/usr/bin/env bash
set -euo pipefail

# =======================
# Configurable variables
# =======================
GRADIO_BASE="${GRADIO_BASE:-https://gradio.mrfusion.rymcg.tech}"  # include subpath if used
GRADIO_API_NAME="${GRADIO_API_NAME:-/generate_audio}"            # your api_name
OUT_FILE="${OUT_FILE:-out.wav}"

# ---- Model inputs (env-tunable) ----
PROMPT_TEXT="${PROMPT_TEXT:-}"           # transcript for the prompt audio (if used)
PROMPT_URL="${PROMPT_URL:-}"             # URL to an audio file for prompt; leave empty for none

MAX_NEW_TOKENS="${MAX_NEW_TOKENS:-860}"
CFG_SCALE="${CFG_SCALE:-1}"
TEMPERATURE="${TEMPERATURE:-1}"
TOP_P="${TOP_P:-0.7}"
CFG_FILTER_TOP_K="${CFG_FILTER_TOP_K:-15}"
SPEED_FACTOR="${SPEED_FACTOR:-0.8}"
SEED="${SEED:-3}"                         # use -1 for random

# Optional cookie jar (if your app uses login)
COOKIES="${COOKIES:-}"                    # e.g., /tmp/gradio.cookies

# =======================
# Helpers
# =======================
_curl() {
  if [[ -n "${COOKIES}" ]]; then
    curl -sS -c "$COOKIES" -b "$COOKIES" "$@"
  else
    curl -sS "$@"
  fi
}

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 127; }; }

# =======================
# Main: read TEXT from STDIN/arg/env
# =======================
gradio_tts() {
  require jq
  local base="$GRADIO_BASE"
  local api="$GRADIO_API_NAME"

  # 1) stdin → 2) first arg → 3) $TEXT env
  local TEXT_INPUT=""
  if [ -t 0 ]; then
    # no stdin; check arg/env
    if [[ $# -ge 1 && -n "${1:-}" ]]; then
      TEXT_INPUT="$1"
    elif [[ -n "${TEXT:-}" ]]; then
      TEXT_INPUT="$TEXT"
    else
      echo "Usage: echo 'text' | gradio_tts   # (preferred)
or:   gradio_tts 'text'
or:   TEXT='text' gradio_tts" >&2
      return 2
    fi
  else
    TEXT_INPUT="$(cat)"
  fi

  # File object for prompt audio (or null)
  local file_json
  if [[ -n "$PROMPT_URL" ]]; then
    file_json=$(jq -nc --arg url "$PROMPT_URL" '{path:$url, meta:{_type:"gradio.FileData"}}')
  else
    file_json="null"
  fi

  # Build payload
  local payload
  payload=$(jq -nc \
    --arg text "$TEXT_INPUT" \
    --arg ptext "$PROMPT_TEXT" \
    --argjson file "$file_json" \
    --argjson max "$MAX_NEW_TOKENS" \
    --argjson cfg "$CFG_SCALE" \
    --argjson temp "$TEMPERATURE" \
    --argjson topp "$TOP_P" \
    --argjson topk "$CFG_FILTER_TOP_K" \
    --argjson speed "$SPEED_FACTOR" \
    --argjson seed "$SEED" \
    '{data:[$text,$ptext,$file,$max,$cfg,$temp,$topp,$topk,$speed,$seed]}')

  # Kick job → event_id
  local post_resp event_id
  post_resp=$(_curl -X POST "$base/call$api" -H 'Content-Type: application/json' -d "$payload")
  event_id=$(jq -r '.event_id // empty' <<<"$post_resp")
  if [[ -z "$event_id" ]]; then
    echo "ERROR: No event_id returned. Response was:" >&2
    echo "$post_resp" >&2
    return 1
  fi
  echo "event_id: $event_id" >&2

  # Stream → grab first file URL
  local url
  url=$(_curl -N "$base/call$api/$event_id" | awk -F\" '/"url":/ {print $4; exit}')
  if [[ -z "$url" ]]; then
    echo "ERROR: No file URL found in stream. Ensure your gr.Audio output has type=\"filepath\"." >&2
    return 1
  fi
  echo "file url: $url" >&2

  # Download
  _curl -L "$url" -o "$OUT_FILE"
  echo "$OUT_FILE"
}
