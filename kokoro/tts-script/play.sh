#!/usr/bin/env bash
set -Eeuo pipefail

READ_CMD="${READ_CMD:-./read.sh}"
GAP_MS="${GAP_MS:-250}"

OUTDIR=""
CONCAT_OUT=""
QUIET=false

usage() {
  cat <<'USAGE'
play.sh - Render (skip existing), normalize, concatenate with gaps, and play a single WAV.

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
  TARGET_RATE            Force sample rate for output (e.g., 48000). Default: first clip's rate.
  TARGET_CH              Force channels for output (1=mono, 2=stereo). Default: first clip's channels.

Requires:
  sox (for normalization/concat), and an audio player (mpv/ffplay/play/aplay) to auto-play.
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
command -v sox >/dev/null 2>&1 || { echo "ERROR: 'sox' is required (concat/normalize)." >&2; exit 1; }
[[ -r "$FILE" ]] || { echo "ERROR: cannot read file: $FILE" >&2; exit 1; }
[[ "$GAP_MS" =~ ^[0-9]+$ ]] || { echo "ERROR: --gap-ms must be non-negative integer (ms)"; exit 1; }

# ---------- derive ----------
dir=$(dirname -- "$FILE")
basefile=$(basename -- "$FILE")
prefix="${basefile%.*}"
[[ -z "$OUTDIR" ]] && OUTDIR="$dir"
mkdir -p -- "$OUTDIR"
[[ -z "$CONCAT_OUT" ]] && CONCAT_OUT="$OUTDIR/${prefix}-ALL.wav"

$QUIET || {
  echo "Input: $FILE"
  echo "Output dir: $OUTDIR"
  echo "Prefix: $prefix"
  echo "Gap: ${GAP_MS} ms"
  echo "Combined output: $CONCAT_OUT"
}

# ---------- render (skip existing) ----------
"$READ_CMD" --skip-existing -o "$OUTDIR" "$FILE"

# ---------- collect ----------
shopt -s nullglob
files=( "$OUTDIR/${prefix}-"*.wav )
shopt -u nullglob
(( ${#files[@]} > 0 )) || { echo "No rendered files in $OUTDIR matching ${prefix}-*.wav" >&2; exit 1; }

# ---------- choose target format (rate/ch) ----------
detect_rate() { sox --i -r "$1"; }
detect_ch()   { sox --i -c "$1"; }

rate="${TARGET_RATE:-$(detect_rate "${files[0]}")}"
ch="${TARGET_CH:-$(detect_ch   "${files[0]}")}"
$QUIET || echo "Target format: ${rate} Hz, ${ch} channel(s)"

# ---------- temp workspace ----------
tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

# ---------- normalize each clip to target format ----------
normalized=()
for f in "${files[@]}"; do
  fr=$(detect_rate "$f") || fr=""
  fc=$(detect_ch "$f")   || fc=""
  if [[ "$fr" != "$rate" || "$fc" != "$ch" ]]; then
    out="$tmpdir/$(basename "$f")"
    $QUIET || echo "Normalize: $(basename "$f") -> ${rate} Hz, ${ch} ch"
    # Convert sample rate & channels; keep PCM WAV default
    sox "$f" -r "$rate" -c "$ch" "$out"
    normalized+=("$out")
  else
    normalized+=("$f")
  fi
done

# ---------- build silence gap with matching format ----------
gap_secs=$(awk -v m="$GAP_MS" 'BEGIN{printf "%.6f", m/1000}')
silence="$tmpdir/gap_${GAP_MS}ms.wav"
sox -n -r "$rate" -c "$ch" "$silence" trim 0 "$gap_secs"

# ---------- concat sequence: clip1, gap, clip2, gap, ..., last clip ----------
concat_inputs=()
for ((i=0; i<${#normalized[@]}; i++)); do
  concat_inputs+=("${normalized[i]}")
  (( i < ${#normalized[@]}-1 )) && concat_inputs+=("$silence")
done

$QUIET || echo "Concatenating ${#files[@]} clip(s)…"
sox "${concat_inputs[@]}" -r "$rate" -c "$ch" "$CONCAT_OUT"

$QUIET || echo "Wrote: $CONCAT_OUT"

# ---------- play ----------
pick_player() {
  if command -v mpv >/dev/null 2>&1; then PLAYER_ARR=(mpv --really-quiet --no-video); return 0; fi
  if command -v ffplay >/dev/null 2>&1; then PLAYER_ARR=(ffplay -nodisp -autoexit -loglevel error); return 0; fi
  if command -v play >/dev/null 2>&1; then PLAYER_ARR=(play -q); return 0; fi
  if command -v aplay >/dev/null 2>&1; then PLAYER_ARR=(aplay -q); return 0; fi
  return 1
}

if pick_player; then
  $QUIET || echo "Playing combined file…"
  # shellcheck disable=SC2086
  "${PLAYER_ARR[@]}" "$CONCAT_OUT" </dev/null || echo "WARNING: player failed on: $CONCAT_OUT" >&2
else
  echo "NOTE: no player found (mpv/ffplay/play/aplay). Skipping playback." >&2
fi
