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

usage() {
  cat <<'USAGE'
read.sh - Generate one WAV per *paragraph* with voice + interpolation directives (parallel).

Usage:
  ./read.sh [options] FILE.txt

Directives in FILE.txt:

  ## name: voice expression     # define a voice preset
  # name                        # switch current voice to that preset

  ## key=value                  # define a text interpolation: replace every 'key' with 'value'
                                # e.g. "## d.rymcg.tech=dee dot rye mcgee dot tech"

Paragraphs:
  - One or more blank lines separate paragraphs.
  - Each paragraph is flattened (line wraps removed) and becomes a single audio file.

Output names:
  <prefix>-<NNNNNNN>.wav (7-digit zero padding), where <prefix> is FILE's basename.

Options:
  -o, --outdir DIR       Output directory (default: same dir as FILE)
  -s, --start N          Start index (default: 1)
      --skip-existing    Skip outputs that already exist and are non-empty
      --dry-run          Print actions only (no network calls)
  -j, --jobs N           Parallel jobs for rendering (default: #CPUs)
  -q, --quiet            Reduce output
  -h, --help             Show help

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
command -v "$TTS_CMD" >/dev/null 2>&1 || {
  echo "ERROR: TTS_CMD not found/executable: $TTS_CMD" >&2; exit 1;
}
[[ -r "$FILE" ]] || { echo "ERROR: cannot read file: $FILE" >&2; exit 1; }
[[ "$START" =~ ^[0-9]+$ ]] || { echo "ERROR: --start must be integer" >&2; exit 1; }
if [[ -n "$JOBS" ]] && ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: --jobs must be a positive integer" >&2
  exit 1
fi

# CPU count helper (default JOBS)
cpu_count() {
  if command -v nproc >/dev/null 2>&1; then nproc
  elif [[ "$(uname -s)" == "Darwin" ]]; then sysctl -n hw.ncpu
  else getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1
  fi
}
: "${JOBS:=$(cpu_count)}"

# Fallback if wait -n is not available (e.g., old bash): throttle via jobs count
have_wait_n=1
help wait 2>/dev/null | grep -q -- '-n' || have_wait_n=0

# ---- Derive names/paths ----
dir=$(dirname -- "$FILE")
basefile=$(basename -- "$FILE")
prefix="${basefile%.*}"
[[ -z "$OUTDIR" ]] && OUTDIR="$dir"
mkdir -p -- "$OUTDIR"

$QUIET || {
  echo "Input: $FILE"
  echo "Output dir: $OUTDIR"
  echo "Prefix: $prefix"
  echo "Index starts at: $START"
  echo "Jobs: $JOBS"
  $DRY_RUN || echo
}

# ---- Directive storage ----
declare -A VOICE_PRESETS=()   # name -> voice expression
current_voice=""

declare -A INTERP_MAP=()      # key -> value
INTERP_KEYS=()                # preserve order

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
    # escape glob chars for ${var//pattern/repl}
    pat="${key//\\/\\\\}"
    pat="${pat//\*/\\*}"
    pat="${pat//\?/\\?}"
    pat="${pat//[/\\[}"
    out="${out//"$pat"/$val}"
  done
  printf '%s' "$out"
}

# Task queues
TASK_FILES=()
TASK_TEXTS=()
TASK_VOICES=()

queue_paragraph() {
  local text="$1" voice="$2"
  [[ -z "$text" ]] && return 0
  local final idx num out
  final="$(flatten_and_interpolate "$text")"
  idx=$(( START + ${#TASK_FILES[@]} ))
  num=$(printf "%07d" "$idx")
  out="$OUTDIR/${prefix}-${num}.wav"
  TASK_FILES+=( "$out" )
  TASK_TEXTS+=( "$final" )
  TASK_VOICES+=( "$voice" )
}

render_task() {
  local i="$1"
  local out="${TASK_FILES[i]}"
  local text="${TASK_TEXTS[i]}"
  local voice="${TASK_VOICES[i]}"
  local num
  num="$(basename "$out" | sed -E 's/.*-([0-9]{7})\.wav/\1/')"

  if $SKIP_EXISTING && [[ -s "$out" ]]; then
    $QUIET || echo "[$num] exists, skipping: $out"
    return 0
  fi

  if $DRY_RUN; then
    local preview="${text:0:80}"; [[ ${#text} -gt 80 ]] && preview+="…"
    echo "[$num] would write: $out"
    [[ -n "$voice" ]] && echo "       voice: $voice"
    echo "       text: $preview"
    return 0
  fi

  $QUIET || {
    echo "[$num] -> $out"
    [[ -n "$voice" ]] && echo "       voice: $voice"
  }

  if [[ -n "$voice" ]]; then
    "$TTS_CMD" -q -f wav -V "$voice" -o "$out" --text "$text"
  else
    "$TTS_CMD" -q -f wav -o "$out" --text "$text"
  fi
}

# ---- Parse file: directives + paragraphs ----
para=""
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line%$'\r'}  # strip trailing CR

  # Voice preset: "## name: expr"
  if [[ "$line" =~ ^[[:space:]]*##[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*:[[:space:]]*(.+)[[:space:]]*$ ]]; then
    name="${BASH_REMATCH[1]}"
    expr="${BASH_REMATCH[2]}"
    VOICE_PRESETS["$name"]="$expr"
    $QUIET || echo ">> preset defined: $name = $expr"
    continue
  fi

  # Interpolation: "## key=value"
  if [[ "$line" =~ ^[[:space:]]*##[[:space:]]*([^=[:space:]][^=]*)[[:space:]]*=[[:space:]]*(.+)[[:space:]]*$ ]]; then
    key="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"
    key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
    val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
    INTERP_MAP["$key"]="$val"
    INTERP_KEYS+=("$key")
    $QUIET || echo ">> interpolate: '$key' -> '$val'"
    continue
  fi

  # Voice switch: "# name"
  if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*$ ]]; then
    if [[ -n "$para" ]]; then
      queue_paragraph "$para" "$current_voice"
      para=""
    fi
    preset="${BASH_REMATCH[1]}"
    if [[ -n "${VOICE_PRESETS[$preset]+x}" ]]; then
      current_voice="${VOICE_PRESETS[$preset]}"
      $QUIET || echo ">> voice switched to: $preset"
    else
      echo "WARN: unknown voice preset '$preset' (keeping previous voice)" >&2
    fi
    continue
  fi

  # Blank line => paragraph boundary
  if [[ "$line" =~ ^[[:space:]]*$ ]]; then
    if [[ -n "$para" ]]; then
      queue_paragraph "$para" "$current_voice"
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
[[ -n "$para" ]] && queue_paragraph "$para" "$current_voice"

tasks_total=${#TASK_FILES[@]}
if (( tasks_total == 0 )); then
  echo "No paragraphs found (file empty or only directives/blank lines)." >&2
  exit 0
fi

# ---- Parallel rendering (no FIFOs, no hang) ----
fail=0
running=0
pids=()

launch_job() {
  local idx="$1"
  ( render_task "$idx" ) &
  pids+=("$!")
  running=$((running+1))
}

# Throttle using wait -n when available, otherwise jobs-count loop
for i in "${!TASK_FILES[@]}"; do
  # Skip early to avoid launching unneeded jobs
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
      # Portable throttle: wait until fewer than JOBS jobs remain
      while (( $(jobs -r -p | wc -l) >= JOBS )); do sleep 0.05; done
      running=$(jobs -r -p | wc -l)
    fi
  fi
done

# Wait for all remaining jobs
if (( have_wait_n )); then
  while (( running > 0 )); do
    if ! wait -n; then fail=1; fi
    running=$((running-1))
  done
else
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then fail=1; fi
  done
fi

$QUIET || $DRY_RUN || echo "Done. Processed $tasks_total file(s)."
(( fail )) && exit 1 || exit 0
