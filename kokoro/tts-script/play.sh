#!/usr/bin/env bash
set -Eeuo pipefail

READ_CMD="${READ_CMD:-./read.sh}"
GAP_MS="${GAP_MS:-250}"

OUTDIR=""
CONCAT_OUT=""
QUIET=false
TARGET_RATE="${TARGET_RATE:-}"
TARGET_CH="${TARGET_CH:-}"

usage() {
  cat <<'USAGE'
play.sh - Ensure clips exist, ask read.sh to build one combined WAV, then play it.

Usage:
  ./play.sh [options] FILE.txt

Options:
  -o, --outdir DIR       Output directory (default: same dir as FILE.txt)
  -O, --concat-out FILE  Path to combined WAV (default: <OUTDIR>/<prefix>-ALL.wav)
      --gap-ms N         Gap between clips in milliseconds (default: 250)
  -q, --quiet            Less output
  -h, --help             Show this help

Env:
  READ_CMD               Path to read.sh (default: ./read.sh)
  GAP_MS                 Millisecond gap (default: 250)
  TARGET_RATE            Force sample rate for combined output (e.g., 48000)
  TARGET_CH              Force channels for combined output (1 or 2)
USAGE
}

# ---------- parse args ----------
if [[ $# -eq 0 ]]; then usage; exit 2; fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--outdir) OUTDIR="$2"; shift 2;;
    -O|--concat-out) CONCAT_OUT="$2"; shift 2;;
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
command -v "$READ_CMD" >/dev/null 2>&1 || { echo "ERROR: READ_CMD not found: $READ_CMD" >&2; exit 1; }
[[ -r "$FILE" ]] || { echo "ERROR: cannot read file: $FILE" >&2; exit 1; }
[[ "$GAP_MS" =~ ^[0-9]+$ ]] || { echo "ERROR: --gap-ms must be non-negative integer (ms)"; exit 1; }

# ---------- derive ----------
dir=$(dirname -- "$FILE")
basefile=$(basename -- "$FILE")
prefix="${basefile%.*}"
[[ -z "$OUTDIR" ]] && OUTDIR="$dir"
mkdir -p -- "$OUTDIR"
[[ -z "$CONCAT_OUT" ]] && CONCAT_OUT="$OUTDIR/${prefix}.wav"

$QUIET || {
  echo "Input: $FILE"
  echo "Output dir: $OUTDIR"
  echo "Prefix: $prefix"
  echo "Gap: ${GAP_MS} ms"
  echo "Combined output: $CONCAT_OUT"
}

# ---------- ask read.sh to render + build combined ----------
# --skip-existing to avoid re-rendering clips; read.sh will also skip rebuilding combined
# if it already exists and --skip-existing is set.
READ_ARGS=( --skip-existing -o "$OUTDIR" --rm-clips -O "$CONCAT_OUT" --gap-ms "$GAP_MS" )
[[ -n "$TARGET_RATE" ]] && READ_ARGS+=( --target-rate "$TARGET_RATE" )
[[ -n "$TARGET_CH"   ]] && READ_ARGS+=( --target-ch "$TARGET_CH" )

"$READ_CMD" "${READ_ARGS[@]}" "$FILE"

# ---------- pick a player ----------
pick_player() {
  if command -v mpv >/dev/null 2>&1; then PLAYER_ARR=(mpv --really-quiet --no-video); return 0; fi
  if command -v ffplay >/dev/null 2>&1; then PLAYER_ARR=(ffplay -nodisp -autoexit -loglevel error); return 0; fi
  if command -v play >/dev/null 2>&1; then PLAYER_ARR=(play -q); return 0; fi
  if command -v aplay >/dev/null 2>&1; then PLAYER_ARR=(aplay -q); return 0; fi
  return 1
}

if ! [[ -s "$CONCAT_OUT" ]]; then
  echo "ERROR: Combined file not found: $CONCAT_OUT" >&2
  exit 1
fi

if pick_player; then
  $QUIET || echo "Playing combined file…"
  # shellcheck disable=SC2086
  "${PLAYER_ARR[@]}" "$CONCAT_OUT" </dev/null || echo "WARNING: player failed on: $CONCAT_OUT" >&2
else
  echo "NOTE: no player found (mpv/ffplay/play/aplay). Skipping playback." >&2
fi
