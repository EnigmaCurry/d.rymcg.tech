#!/usr/bin/env bash
set -Eeuo pipefail

# Defaults (can be overridden by env or flags)
ENDPOINT="${KOKORO_ENDPOINT:-https://kokoro.example.com/api/v1/audio/speech}"
API_KEY="${KOKORO_API_KEY:-${API_KEY:-}}"
FORMAT="${FORMAT:-wav}"
VOICE="${VOICE:-am_adam*0.5 + am_puck*0.3 + am_fenrir*0.1 + am_onyx*0.1}"
MODEL="${MODEL:-model}"
SPEED="${SPEED:-1}"

OUT_FILE=""
PLAY_AUDIO=false
QUIET=false
INPUT_TEXT=""

usage() {
  cat <<'USAGE'
tts.sh - call Kokoro TTS from shell

Usage:
  echo "Hello world" | tts.sh [options]
  tts.sh --text "Hello world" [options]

Options:
  -o, --output FILE     Save audio to FILE (if omitted and --play given, temp file is used)
  -p, --play            Play the audio after download (default if neither -o nor --play are given)
  -f, --format FMT      Response format (wav|mp3|flac|...); default: $FORMAT
  -V, --voice STR       Voice string; default: "$VOICE"
  -M, --model NAME      Model name; default: $MODEL
  -s, --speed NUM       Speed (number, e.g. 1, 0.9, 1.2); default: $SPEED
  -e, --endpoint URL    Override API endpoint (default from $KOKORO_ENDPOINT or built-in)
  -k, --api-key KEY     API key (or set KOKORO_API_KEY / API_KEY env var)
  -t, --text STR        Read input text from argument instead of stdin
  -q, --quiet           Reduce output
  -h, --help            Show this help

Examples:
  echo "Hello" | tts.sh --play
  echo "Hello" | tts.sh -o hello.wav
  tts.sh --text "Multiline\nokay too" -V 'am_adam*0.7 + am_puck*0.3' -s 1.1 --play
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

pick_player() {
  if command -v mpv >/dev/null 2>&1; then
    echo "mpv --really-quiet --no-video"
  elif command -v ffplay >/dev/null 2>&1; then
    echo "ffplay -nodisp -autoexit -loglevel error"
  elif command -v play >/dev/null 2>&1; then # sox
    echo "play -q"
  elif command -v aplay >/dev/null 2>&1; then
    echo "aplay -q"
  else
    echo ""
  fi
}

# --------- Parse args ---------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output) OUT_FILE="$2"; shift 2;;
    -p|--play)   PLAY_AUDIO=true; shift;;
    -f|--format) FORMAT="$2"; shift 2;;
    -V|--voice)  VOICE="$2"; shift 2;;
    -M|--model)  MODEL="$2"; shift 2;;
    -s|--speed)  SPEED="$2"; shift 2;;
    -e|--endpoint) ENDPOINT="$2"; shift 2;;
    -k|--api-key) API_KEY="$2"; shift 2;;
    -t|--text)   INPUT_TEXT="$2"; shift 2;;
    -q|--quiet)  QUIET=true; shift;;
    -h|--help)   usage; exit 0;;
    --) shift; break;;
    *) echo "Unknown option: $1" >&2; usage; exit 2;;
  esac
done

require_cmd curl
require_cmd jq

# Validate speed is numeric-ish
if ! [[ "$SPEED" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "ERROR: --speed must be numeric (got: $SPEED)" >&2
  exit 1
fi

# Gather input text (stdin if not provided via --text)
if [[ -z "$INPUT_TEXT" ]]; then
  if [ -t 0 ]; then
    echo "ERROR: No input text provided on stdin. Use --text or pipe text." >&2
    exit 1
  fi
  # Read all of stdin into a variable
  INPUT_TEXT="$(cat)"
fi

# API key required
if [[ -z "${API_KEY:-}" ]]; then
  echo "ERROR: Missing API key. Pass --api-key or set KOKORO_API_KEY / API_KEY." >&2
  exit 1
fi

# Decide default action: if neither --play nor -o given, default to output
if ! $PLAY_AUDIO && [[ -z "$OUT_FILE" ]]; then
  PLAY_AUDIO=true
fi

# Prepare output file (temp if needed)
TMP_CREATED=false
if [[ -z "$OUT_FILE" ]]; then
  OUT_FILE="$(mktemp --suffix=".$FORMAT")"
  TMP_CREATED=true
fi

# Build JSON payload safely with jq (handles newlines/quotes)
payload="$(jq -n \
  --arg input "$INPUT_TEXT" \
  --arg voice "$VOICE" \
  --arg model "$MODEL" \
  --arg format "$FORMAT" \
  --argjson speed "$SPEED" \
  '{input:$input, voice:$voice, model:$model, speed:$speed, response_format:$format}')"

# Make the request
# -sS               quiet + show errors
# --fail-with-body  non-2xx -> exit 22 and print body to stderr
# timeouts to avoid hanging forever
if ! curl -sS --fail-with-body \
  --connect-timeout 10 --max-time 180 \
  -X POST "$ENDPOINT" \
  -H 'content-type: application/json' \
  -H "authorization: Bearer ${API_KEY}" \
  --data-binary "$payload" \
  -o "$OUT_FILE"
then
  # If we created a temp file, clean it on error
  $TMP_CREATED && rm -f "$OUT_FILE" || true
  exit 1
fi

# play or output:
if $PLAY_AUDIO; then
  PLAYER="$(pick_player)"
  if [[ -z "$PLAYER" ]]; then
    echo "NOTE: No audio player found (mpv/ffplay/play/aplay). File saved to: $OUT_FILE" >&2
    exit 0
  fi
  # shellcheck disable=SC2086
  if $PLAYER "$OUT_FILE" </dev/null; then
      rm -f "${OUT_FILE}"
  else
    echo "WARNING: Failed to play audio. File saved to: $OUT_FILE" >&2
  fi
else
    $QUIET || echo "Wrote: $OUT_FILE"
fi
