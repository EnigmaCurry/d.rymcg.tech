#!/usr/bin/env bash
set -Eeuo pipefail

# TTS command; keep it as a single program path (no inline args).
# Pass endpoint/key via env (KOKORO_ENDPOINT, KOKORO_API_KEY) to your tts.sh.
TTS_CMD="${TTS_CMD:-./tts.sh}"

OUTDIR=""
START=1
SKIP_EXISTING=false
DRY_RUN=false
QUIET=false
JOBS="${JOBS:-}"

# Concatenation options (optional)
CONCAT_OUT=""
GAP_MS=250
TARGET_RATE=""
TARGET_CH=""
RM_CLIPS=false

usage() {
  cat <<'USAGE'
read.sh - Generate one WAV per *paragraph* with voice + interpolation directives (parallel).
          Optionally concatenate all clips into a single WAV with silence gaps.
          Supports per-voice pitch: "## name: pitch=0.90 am_adam*0.5 + ..."

Usage:
  ./read.sh [options] FILE.txt

Directives in FILE.txt:

  ## name: pitch=X.XX voice expression   # define a voice preset + optional pitch multiplier
  # name                                 # switch current voice to that preset

  ## key=value                           # define a text interpolation: replace every 'key' with 'value'
                                         # e.g. "## d.rymcg.tech=dee dot rye mcgee dot tech"

Paragraphs:
  - One or more blank lines separate paragraphs.
  - Each paragraph is flattened (line wraps removed) and becomes a single audio file.

Output names:
  <prefix>-<NNNNNNN>.wav (7-digit zero padding), where <prefix> is FILE's basename.

Options:
  -o, --outdir DIR       Output directory for per-paragraph WAVs (default: same dir as FILE)
  -s, --start N          Start index (default: 1)
      --skip-existing    Skip outputs that already exist and are non-empty
      --dry-run          Print actions only (no network calls)
  -j, --jobs N           Parallel jobs for rendering (default: #CPUs)
  -q, --quiet            Reduce output
  -h, --help             Show help

Concatenation (optional):
  -O, --concat-out FILE  Write a single combined WAV of all clips
      --gap-ms N         Milliseconds of silence between clips (default: 250)
      --target-rate HZ   Force sample rate for combined output (default: first clip's rate)
      --target-ch N      Force channels for combined output (1=mono, 2=stereo; default: first clip's)
      --rm-clips         After successful concat, delete intermediate per-paragraph WAVs
Env:
  TTS_CMD                Path to TTS tool (default: ./tts.sh). Must support:
                         -o FILE -f wav [ -V VOICE ] --text "..."
  JOBS                   Parallel jobs override
USAGE
}

# ---- Parse args ----
if [[ $# -eq 0 ]]; then usage; exit 2; fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--outdir) OUTDIR="$2"; shift 2;;
    -s|--start)  START="$2"; shift 2;;
    --skip-existing) SKIP_EXISTING=true; shift;;
    --dry-run)   DRY_RUN=true; shift;;
    -j|--jobs)   JOBS="$2"; shift 2;;
    -q|--quiet)  QUIET=true; shift;;
    -O|--concat-out) CONCAT_OUT="$2"; shift 2;;
    --gap-ms)    GAP_MS="$2"; shift 2;;
    --target-rate) TARGET_RATE="$2"; shift 2;;
    --rm-clips)   RM_CLIPS=true; shift;;
    --target-ch)  TARGET_CH="$2"; shift 2;;
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

# ---- Validate ----
command -v "$TTS_CMD" >/dev/null 2>&1 || { echo "ERROR: TTS_CMD not found/executable: $TTS_CMD" >&2; exit 1; }
[[ -r "$FILE" ]] || { echo "ERROR: cannot read file: $FILE" >&2; exit 1; }
[[ "$START" =~ ^[0-9]+$ ]] || { echo "ERROR: --start must be integer" >&2; exit 1; }
if [[ -n "$JOBS" ]] && ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then echo "ERROR: --jobs must be a positive integer" >&2; exit 1; fi
if ! [[ "$GAP_MS" =~ ^[0-9]+$ ]]; then echo "ERROR: --gap-ms must be non-negative integer (ms)" >&2; exit 1; fi
if [[ -n "$TARGET_RATE" ]] && ! [[ "$TARGET_RATE" =~ ^[1-9][0-9]*$ ]]; then echo "ERROR: --target-rate must be positive integer (Hz)" >&2; exit 1; fi
if [[ -n "$TARGET_CH" ]] && ! [[ "$TARGET_CH" =~ ^[12]$ ]]; then echo "ERROR: --target-ch must be 1 or 2" >&2; exit 1; fi

# CPU count helper (default JOBS)
cpu_count() {
  if command -v nproc >/dev/null 2>&1; then nproc
  elif [[ "$(uname -s)" == "Darwin" ]]; then sysctl -n hw.ncpu
  else getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1
  fi
}
: "${JOBS:=$(cpu_count)}"

# wait -n availability
have_wait_n=1
help wait 2>/dev/null | grep -q -- '-n' || have_wait_n=0

# ---- Derive names/paths ----
dir=$(dirname -- "$FILE")
basefile=$(basename -- "$FILE")
prefix="${basefile%.*}"
[[ -z "$OUTDIR" ]] && OUTDIR="$dir"
mkdir -p -- "$OUTDIR"
[[ -z "$CONCAT_OUT" ]] || CONCAT_OUT="$(realpath -m "$CONCAT_OUT" 2>/dev/null || echo "$CONCAT_OUT")"

$QUIET || {
  echo "Input: $FILE"
  echo "Output dir: $OUTDIR"
  echo "Prefix: $prefix"
  echo "Index starts at: $START"
  echo "Jobs: $JOBS"
  [[ -n "$CONCAT_OUT" ]] && {
    echo "Concat output: $CONCAT_OUT"
    echo "Gap: ${GAP_MS} ms"
    [[ -n "$TARGET_RATE" ]] && echo "Target rate: $TARGET_RATE Hz"
    [[ -n "$TARGET_CH"  ]] && echo "Target ch:   $TARGET_CH"
  }
  $DRY_RUN || echo
}

# ---- Directive storage ----
# Per-preset voice expression (for TTS) and pitch multiplier
declare -A VOICE_EXPR   # name -> voice expression (with 'pitch=...' stripped)
declare -A VOICE_PITCH  # name -> pitch multiplier (string), default "1"
current_voice_expr=""
current_pitch="1"

# Interpolations
declare -A INTERP_MAP
INTERP_KEYS=()

# ---- Helpers ----
flatten_and_interpolate() {
  local raw="$1"
  local flat out key val pat
  flat=$(printf '%s' "$raw" \
    | tr '\n' ' ' \
    | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$$//')
  out="$flat"
  for key in "${INTERP_KEYS[@]}"; do
    val="${INTERP_MAP[$key]}"
    pat="${key//\\/\\\\}"; pat="${pat//\*/\\*}"; pat="${pat//\?/\\?}"; pat="${pat//[/\\[}"
    out="${out//"$pat"/$val}"
  done
  printf '%s' "$out"
}

apply_pitch_if_needed() {
  local out="$1" pitch="$2"
  # near-1 check
  local near1
  near1=$(awk -v p="$pitch" 'BEGIN{d=p-1;if(d<0)d=-d;print(d<1e-6?"1":"0")}')
  [[ "$near1" == "1" ]] && return 0
  if ! command -v sox >/dev/null 2>&1; then
    if [[ -z "${__warn_no_sox_pitch:-}" ]]; then
      echo "WARN: sox not found; cannot apply pitch=$pitch to $out (leaving unmodified)." >&2
      __warn_no_sox_pitch=1
    fi
    return 0
  fi
  local cents
  if ! cents=$(awk -v p="$pitch" 'BEGIN{ if(p<=0) exit 1; printf "%.6f", 1200*log(p)/log(2) }'); then
    echo "WARN: invalid pitch multiplier '$pitch' (must be > 0). Skipping pitch on $out." >&2
    return 0
  fi
  $QUIET || echo "       pitch: x$pitch (${cents} cents)"
  local tmp; tmp="$(mktemp --suffix=.wav)"
  if sox "$out" "$tmp" pitch "$cents"; then
    mv -f "$tmp" "$out"
  else
    echo "WARN: sox pitch processing failed for: $out" >&2
    rm -f "$tmp" || true
  fi
}

# Task queues
TASK_FILES=()   # output filenames
TASK_TEXTS=()   # final text
TASK_VOICES=()  # voice expression for TTS
TASK_PITCHES=() # pitch multiplier as string

queue_paragraph() {
  local text="$1" voice_expr="$2" pitch="$3"
  [[ -z "$text" ]] && return 0
  local final idx num out
  final="$(flatten_and_interpolate "$text")"
  idx=$(( START + ${#TASK_FILES[@]} ))
  num=$(printf "%07d" "$idx")
  out="$OUTDIR/${prefix}-${num}.wav"
  TASK_FILES+=( "$out" )
  TASK_TEXTS+=( "$final" )
  TASK_VOICES+=( "$voice_expr" )
  TASK_PITCHES+=( "${pitch:-1}" )
}

render_task() {
  local i="$1"
  local out="${TASK_FILES[i]}"
  local text="${TASK_TEXTS[i]}"
  local voice_expr="${TASK_VOICES[i]}"
  local pitch_mul="${TASK_PITCHES[i]}"
  local num; num="$(basename "$out" | sed -E 's/.*-([0-9]{7})\.wav/\1/')"

  if $SKIP_EXISTING && [[ -s "$out" ]]; then
    $QUIET || echo "[$num] exists, skipping: $out"
    return 0
  fi

  if $DRY_RUN; then
    local preview="${text:0:80}"; [[ ${#text} -gt 80 ]] && preview+="…"
    echo "[$num] would write: $out"
    [[ -n "$voice_expr" ]] && echo "       voice: $voice_expr"
    awk -v p="$pitch_mul" 'BEGIN{d=p-1;if(d<0)d=-d; if(d>=1e-6) printf "       pitch: x%s\n", p}'
    echo "       text: $preview"
    return 0
  fi

  $QUIET || {
    echo "[$num] -> $out"
    [[ -n "$voice_expr" ]] && echo "       voice: $voice_expr"
  }

  if [[ -n "$voice_expr" ]]; then
    "$TTS_CMD" -q -f wav -V "$voice_expr" -o "$out" --text "$text"
  else
    "$TTS_CMD" -q -f wav -o "$out" --text "$text"
  fi

  # Post-process pitch (if requested)
  apply_pitch_if_needed "$out" "$pitch_mul"
}

# ---- Parse file: directives + paragraphs ----
para=""
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line%$'\r'}  # strip trailing CR

  # Voice preset: "## name: [pitch=...] expr"
  if [[ "$line" =~ ^[[:space:]]*##[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*:[[:space:]]*(.+)[[:space:]]*$ ]]; then
    name="${BASH_REMATCH[1]}"
    expr_raw="${BASH_REMATCH[2]}"

    # Extract optional pitch=NUM anywhere in the expr string
    pitch_val="1"
    if [[ "$expr_raw" =~ (^|[[:space:]])pitch=([0-9]+([.][0-9]+)?) ]]; then
      pitch_val="${BASH_REMATCH[2]}"
    fi
    # Strip all pitch=... tokens and tidy spaces
    expr_clean="$(sed -E 's/(^|[[:space:]])pitch=([0-9]+([.][0-9]+)?)//g; s/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$$//' <<<"$expr_raw")"

    VOICE_EXPR["$name"]="$expr_clean"
    VOICE_PITCH["$name"]="$pitch_val"
    $QUIET || echo ">> preset defined: $name = pitch=$pitch_val; voice=\"${expr_clean}\""
    continue
  fi

  # Interpolation: "## key=value"
  if [[ "$line" =~ ^[[:space:]]*##[[:space:]]*([^=[:space:]][^=]*)[[:space:]]*=[[:space:]]*(.+)[[:space:]]*$ ]]; then
    key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
    key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
    val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
    INTERP_MAP["$key"]="$val"; INTERP_KEYS+=("$key")
    $QUIET || echo ">> interpolate: '$key' -> '$val'"
    continue
  fi

  # Voice switch: "# name"
  if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*$ ]]; then
    if [[ -n "$para" ]]; then
      queue_paragraph "$para" "$current_voice_expr" "$current_pitch"
      para=""
    fi
    preset="${BASH_REMATCH[1]}"
    if [[ -n "${VOICE_EXPR[$preset]+x}" ]]; then
      current_voice_expr="${VOICE_EXPR[$preset]}"
      current_pitch="${VOICE_PITCH[$preset]:-1}"
    else
      echo "WARN: unknown voice preset '$preset' (keeping previous voice)" >&2
    fi
    continue
  fi

  # Blank line => paragraph boundary
  if [[ "$line" =~ ^[[:space:]]*$ ]]; then
    if [[ -n "$para" ]]; then
      queue_paragraph "$para" "$current_voice_expr" "$current_pitch"
      para=""
    fi
    continue
  fi

  # Accumulate content
  if [[ -z "$para" ]]; then
    para="$line"
  else
    para+=$'\n'"$line"
  fi
done < "$FILE"
[[ -n "$para" ]] && queue_paragraph "$para" "$current_voice_expr" "$current_pitch"

tasks_total=${#TASK_FILES[@]}
if (( tasks_total == 0 )); then
  echo "No paragraphs found (file empty or only directives/blank lines)." >&2
  exit 0
fi

# ---- Parallel rendering ----
fail=0
running=0
pids=()

launch_job() { ( render_task "$1" ) & pids+=("$!"); running=$((running+1)); }

for i in "${!TASK_FILES[@]}"; do
  if $SKIP_EXISTING && [[ -s "${TASK_FILES[i]}" ]]; then
    num=$(basename "${TASK_FILES[i]}" | sed -E 's/.*-([0-9]{7})\.wav/\1/')
    $QUIET || echo "[$num] exists, skipping: ${TASK_FILES[i]}"
    continue
  fi
  launch_job "$i"
  if (( running >= JOBS )); then
    if (( have_wait_n )); then
      if ! wait -n; then fail=1; fi
      running=$((running-1))
    else
      while (( $(jobs -r -p | wc -l) >= JOBS )); do sleep 0.05; done
      running=$(jobs -r -p | wc -l)
    fi
  fi
done

# Wait out remaining jobs
if (( have_wait_n )); then
  while (( running > 0 )); do
    if ! wait -n; then fail=1; fi
    running=$((running-1))
  done
else
  for pid in "${pids[@]}"; do if ! wait "$pid"; then fail=1; fi; done
fi

$QUIET || $DRY_RUN || echo "Rendered $tasks_total clip(s)."

# ---- Concatenate (optional) ----
if [[ -n "$CONCAT_OUT" ]]; then
  if $SKIP_EXISTING && [[ -s "$CONCAT_OUT" ]]; then
    $QUIET || echo "Combined exists, skipping: $CONCAT_OUT"
    exit $fail
  fi

  command -v sox >/dev/null 2>&1 || { echo "ERROR: --concat-out requires 'sox'." >&2; exit 1; }

  # Collect clips in order (we already know their names)
  clips=( "${TASK_FILES[@]}" )
  (( ${#clips[@]} > 0 )) || { echo "ERROR: No clips to concatenate." >&2; exit 1; }

  detect_rate() { sox --i -r "$1"; }
  detect_ch()   { sox --i -c "$1"; }

  rate="${TARGET_RATE:-$(detect_rate "${clips[0]}")}"
  ch="${TARGET_CH:-$(detect_ch   "${clips[0]}")}"
  $QUIET || echo "Concat format: ${rate} Hz, ${ch} channel(s); gap ${GAP_MS} ms"

  tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
  normalized=()
  for f in "${clips[@]}"; do
    fr=$(detect_rate "$f" || echo "")
    fc=$(detect_ch "$f"   || echo "")
    if [[ "$fr" != "$rate" || "$fc" != "$ch" ]]; then
      out="$tmpdir/$(basename "$f")"
      $QUIET || echo "Normalize: $(basename "$f") -> ${rate} Hz, ${ch} ch"
      sox "$f" -r "$rate" -c "$ch" "$out"
      normalized+=( "$out" )
    else
      normalized+=( "$f" )
    fi
  done

  gap_secs=$(awk -v m="$GAP_MS" 'BEGIN{printf "%.6f", m/1000}')
  silence="$tmpdir/gap_${GAP_MS}ms.wav"
  sox -n -r "$rate" -c "$ch" "$silence" trim 0 "$gap_secs"

  concat_inputs=()
  for ((i=0; i<${#normalized[@]}; i++)); do
    concat_inputs+=("${normalized[i]}")
    (( i < ${#normalized[@]}-1 )) && concat_inputs+=("$silence")
  done

  $QUIET || echo "Concatenating ${#normalized[@]} clip(s) -> $CONCAT_OUT"
  sox "${concat_inputs[@]}" -r "$rate" -c "$ch" "$CONCAT_OUT"
  $QUIET || echo "Wrote: $CONCAT_OUT"

  if $RM_CLIPS; then
    $QUIET || echo "Removing intermediate clips..."
    for f in "${clips[@]}"; do
      # Paranoia: never remove the combined file if it's somehow in the list
      if [[ -e "$CONCAT_OUT" ]] && [[ "$f" -ef "$CONCAT_OUT" ]]; then
        continue
      fi
      if $DRY_RUN; then
        echo "rm -f -- $f"
      else
        rm -f -- "$f"
      fi
    done
  fi

fi

(( fail )) && exit 1 || exit 0
