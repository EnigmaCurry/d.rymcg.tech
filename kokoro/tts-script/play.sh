#!/usr/bin/env bash
set -Eeuo pipefail

# Which reader to invoke (can override: READ_CMD=/path/to/read.sh)
READ_CMD="${READ_CMD:-./read.sh}"

# Gap between clips in milliseconds (override via --gap-ms or GAP_MS env)
GAP_MS="${GAP_MS:-250}"

OUTDIR=""
QUIET=false

usage() {
  cat <<'USAGE'
play.sh - Render (skip existing) and play a text file's paragraphs in order.

Usage:
  ./play.sh [options] FILE.txt

Options:
  -o, --outdir DIR     Output directory for WAVs (default: same dir as FILE.txt)
      --gap-ms N       Gap between clips in milliseconds (default: 1000)
  -q, --quiet          Less output
  -h, --help           Show this help

Env:
  READ_CMD             Path to read.sh (default: ./read.sh)
  GAP_MS               Millisecond gap between clips (default: 1000)

Notes:
  - Expects files named <prefix>-<NNNNNNN>.wav (7-digit zero padding)
    where <prefix> is FILE's basename without extension.
USAGE
}

# ---------- parse args ----------
if [[ $# -eq 0 ]]; then usage; exit 2; fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--outdir) OUTDIR="$2"; shift 2;;
    --gap-ms)    GAP_MS="$2"; shift 2;;
    -q|--quiet)  QUIET=true; shift;;
    -h|--help)   usage; exit 0;;
    --) shift; break;;
    -*) echo "Unknown option: $1" >&2; usage; exit 2;;
    *) break;;
  esac
done

if [[ $# -lt 1 ]]; then
  echo "ERROR: missing FILE.txt" >&2; usage; exit 2
fi
FILE="$1"

# ---------- validate ----------
command -v "$READ_CMD" >/dev/null 2>&1 || {
  echo "ERROR: READ_CMD not found/executable: $READ_CMD" >&2; exit 1;
}
[[ -r "$FILE" ]] || { echo "ERROR: cannot read file: $FILE" >&2; exit 1; }
[[ "$GAP_MS" =~ ^[0-9]+$ ]] || { echo "ERROR: --gap-ms must be non-negative integer (ms)"; exit 1; }

# ---------- derive paths ----------
dir=$(dirname -- "$FILE")
basefile=$(basename -- "$FILE")
prefix="${basefile%.*}"
[[ -z "$OUTDIR" ]] && OUTDIR="$dir"
mkdir -p -- "$OUTDIR"

$QUIET || echo "Input: $FILE"
$QUIET || echo "Output dir: $OUTDIR"
$QUIET || echo "Prefix: $prefix"
$QUIET || echo "Gap: ${GAP_MS} ms"

# ---------- render (skip existing) ----------
"$READ_CMD" --skip-existing -o "$OUTDIR" "$FILE"

# ---------- collect files ----------
shopt -s nullglob
files=( "$OUTDIR/${prefix}-"*.wav )
shopt -u nullglob

if (( ${#files[@]} == 0 )); then
  echo "No rendered files found matching: $OUTDIR/${prefix}-*.wav" >&2
  exit 1
fi

# ---------- pick a player ----------
pick_player() {
  if command -v mpv >/dev/null 2>&1; then
    PLAYER_ARR=(mpv --really-quiet --no-video)
    return 0
  elif command -v ffplay >/dev/null 2>&1; then
    PLAYER_ARR=(ffplay -nodisp -autoexit -loglevel error)
    return 0
  elif command -v play >/dev/null 2>&1; then
    PLAYER_ARR=(play -q)    # sox
    return 0
  elif command -v aplay >/dev/null 2>&1; then
    PLAYER_ARR=(aplay -q)
    return 0
  fi
  return 1
}
if ! pick_player; then
  echo "ERROR: no audio player found (need mpv, ffplay, play, or aplay)." >&2
  exit 1
fi

# ---------- millisecond sleep helper ----------
# Prefer usleep (microseconds). Fallback to sleep with fractional seconds.
sleep_ms() {
  local ms="$1"
  (( ms <= 0 )) && return 0
  if command -v usleep >/dev/null 2>&1; then
    usleep "$(( ms * 1000 ))"
  else
    # Use awk to format fractional seconds for coreutils sleep
    local secs
    secs=$(awk -v m="$ms" 'BEGIN{printf "%.6f", m/1000}')
    sleep "$secs"
  fi
}

# ---------- play in order with gaps ----------
total=${#files[@]}
$QUIET || echo "Playing $total file(s)…"
for i in "${!files[@]}"; do
  idx=$((i+1))
  f="${files[i]}"
  $QUIET || echo "[$idx/$total] $f"
  # shellcheck disable=SC2086
  "${PLAYER_ARR[@]}" "$f" </dev/null || {
    echo "WARNING: player failed on: $f" >&2
  }
  if (( i < total-1 )); then
    sleep_ms "$GAP_MS"
  fi
done
