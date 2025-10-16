#!/usr/bin/env bash
set -Eeuo pipefail

READ_CMD="${READ_CMD:-./read.sh}"
GAP_MS="${GAP_MS:-250}"

OUTDIR=""
CONCAT_OUT=""
TRANSCODE_MP3=""

QUIET=false
TARGET_RATE="${TARGET_RATE:-}"
TARGET_CH="${TARGET_CH:-}"

# MP3 encode knobs
MP3_Q="${MP3_Q:-2}"                   # 0(best)..9(worst) VBR quality for libmp3lame
OVERWRITE_MP3="${OVERWRITE_MP3:-false}"  # true|false — overwrite existing mp3s

usage() {
  cat <<'USAGE'
play.sh - Ensure clips exist, ask read.sh to build one combined WAV, then play it.

Usage:
  ./play.sh [options] FILE.txt

Options:
  -o, --outdir DIR       Output directory (default: same dir as FILE.txt)
  -O, --concat-out FILE  Path to combined WAV (default: <OUTDIR>/<prefix>.wav)
      --gap-ms N         Gap between clips in milliseconds (default: 250)
  -q, --quiet            Less output
  -h, --help             Show this help

Env:
  READ_CMD               Path to read.sh (default: ./read.sh)
  GAP_MS                 Millisecond gap (default: 250)
  TARGET_RATE            Force sample rate for combined output (e.g., 48000)
  TARGET_CH              Force channels for combined output (1 or 2)

  # MP3 encoding
  MP3_Q                  libmp3lame VBR quality 0..9 (default: 2)
  OVERWRITE_MP3          Overwrite existing mp3s (true|false, default: false)
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

# We'll need ffmpeg for transcoding; check now so failures are early.
command -v ffmpeg >/dev/null 2>&1 || { echo "ERROR: ffmpeg not found in PATH" >&2; exit 1; }

# ---------- derive ----------
dir=$(dirname -- "$FILE")
basefile=$(basename -- "$FILE")
prefix="${basefile%.*}"
[[ -z "$OUTDIR" ]] && OUTDIR="$dir"
mkdir -p -- "$OUTDIR"
[[ -z "$CONCAT_OUT" ]] && CONCAT_OUT="$OUTDIR/${prefix}.wav"
[[ -z "$TRANSCODE_MP3" ]] && TRANSCODE_MP3="$OUTDIR/${prefix}.mp3"

$QUIET || {
  echo "Input: $FILE"
  echo "Output dir: $OUTDIR"
  echo "Prefix: $prefix"
  echo "Gap: ${GAP_MS} ms"
  echo "Combined output: $CONCAT_OUT"
  echo "Combined mp3: $TRANSCODE_MP3"
  echo "MP3_Q: $MP3_Q  OVERWRITE_MP3: $OVERWRITE_MP3"
}

# ---------- ask read.sh to render + build combined ----------
READ_ARGS=( --skip-existing -o "$OUTDIR" -O "$CONCAT_OUT" --gap-ms "$GAP_MS" )
[[ -n "$TARGET_RATE" ]] && READ_ARGS+=( --target-rate "$TARGET_RATE" )
[[ -n "$TARGET_CH"   ]] && READ_ARGS+=( --target-ch "$TARGET_CH" )

"$READ_CMD" "${READ_ARGS[@]}" "$FILE"

# ---------- helpers ----------
pick_player() {
  if command -v mpv >/dev/null 2>&1; then PLAYER_ARR=(mpv --really-quiet --no-video); return 0; fi
  if command -v ffplay >/dev/null 2>&1; then PLAYER_ARR=(ffplay -nodisp -autoexit -loglevel error); return 0; fi
  if command -v play >/dev/null 2>&1; then PLAYER_ARR=(play -q); return 0; fi
  if command -v aplay >/dev/null 2>&1; then PLAYER_ARR=(aplay -q); return 0; fi
  return 1
}

transcode_wav_to_mp3() {
  local in_wav="$1" out_mp3="$2"
  if [[ -s "$out_mp3" && "$OVERWRITE_MP3" != "true" ]]; then
    $QUIET || echo "Skip (exists): $out_mp3"
    return 0
  fi
  $QUIET || echo "Encoding: $in_wav -> $out_mp3"
  ffmpeg -hide_banner -loglevel error \
    -i "$in_wav" -codec:a libmp3lame -qscale:a "$MP3_Q" \
    -y "$out_mp3"
}

# ---------- ensure combined exists ----------
if ! [[ -s "$CONCAT_OUT" ]]; then
  echo "ERROR: Combined file not found: $CONCAT_OUT" >&2
  exit 1
fi

# ---------- transcode: combined WAV -> MP3 ----------
transcode_wav_to_mp3 "$CONCAT_OUT" "$TRANSCODE_MP3"

# ---------- transcode: all clip WAVs matching $OUTDIR/${prefix}-*.wav ----------
$QUIET || echo "Encoding all clip WAVs in: $OUTDIR matching ${prefix}-*.wav"
found_any=false
# Use find -print0 to be robust to spaces/newlines
while IFS= read -r -d '' wav; do
  found_any=true
  mp3="${wav%.wav}.mp3"
  transcode_wav_to_mp3 "$wav" "$mp3"
done < <(find "$OUTDIR" -maxdepth 1 -type f -name "${prefix}-*.wav" -print0)

if ! $found_any; then
  $QUIET || echo "No clip files matched: ${OUTDIR}/${prefix}-*.wav"
fi

# ---------- playback ----------
if pick_player; then
  $QUIET || echo "Playing combined file…"
  "${PLAYER_ARR[@]}" "$CONCAT_OUT" </dev/null || echo "WARNING: player failed on: $CONCAT_OUT" >&2
else
  echo "NOTE: no player found (mpv/ffplay/play/aplay). Skipping playback." >&2
fi
