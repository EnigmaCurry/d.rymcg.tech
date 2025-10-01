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

usage() {
  cat <<'USAGE'
read.sh - Generate one WAV per *paragraph* and support voice directives.

Usage:
  ./read.sh [options] FILE.txt

Directives in FILE.txt:
  ## name: voice expression     # define a preset (e.g., "## narrator: am_adam*0.5 + am_puck*0.5")
  # name                        # switch current voice to that preset for following paragraphs

Paragraphs:
  - One or more blank lines separate paragraphs.
  - Each paragraph becomes a single audio file.

Output names:
  <prefix>-<NNNNNNN>.wav (7-digit zero padding), where <prefix> is FILE's basename.

Options:
  -o, --outdir DIR       Output directory (default: same dir as FILE)
  -s, --start N          Start index (default: 1)
      --skip-existing    Skip outputs that already exist and are non-empty
      --dry-run          Print actions only
  -q, --quiet            Reduce output
  -h, --help             Show help

Env:
  TTS_CMD                Path to TTS tool (default: ./tts.sh). Must support:
                         -o FILE -f wav [ -V VOICE ] --text "..."
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
    -q|--quiet)  QUIET=true; shift;;
    -h|--help)   usage; exit 0;;
    --) shift; break;;
    -*)
      echo "Unknown option: $1" >&2; usage; exit 2;;
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

# ---- Derive names/paths ----
dir=$(dirname -- "$FILE")
basefile=$(basename -- "$FILE")
prefix="${basefile%.*}"
[[ -z "$OUTDIR" ]] && OUTDIR="$dir"
mkdir -p -- "$OUTDIR"

$QUIET || echo "Input: $FILE"
$QUIET || echo "Output dir: $OUTDIR"
$QUIET || echo "Prefix: $prefix"
$QUIET || echo "Index starts at: $START"
$QUIET || $DRY_RUN || echo

# ---- Voice preset storage ----
# Bash 4+ associative array of presets: name -> voice expression
declare -A VOICE_PRESETS=()
current_voice=""

emit_paragraph() {
  local text="$1"
  local voice="$2"
  [[ -z "$text" ]] && return 0

  # Flatten paragraph: join wrapped lines into one line.
  # - Replace all newlines with spaces
  # - Collapse multiple whitespace to a single space
  # - Trim leading/trailing spaces
  local flat
  flat=$(printf '%s' "$text" \
    | tr '\n' ' ' \
    | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$$//')

  local num out
  num=$(printf "%07d" "$index")
  out="$OUTDIR/${prefix}-${num}.wav"

  if $SKIP_EXISTING && [[ -s "$out" ]]; then
    $QUIET || echo "[$num] exists, skipping: $out"
  else
    if $DRY_RUN; then
      # Show preview of flattened text
      local preview="${flat:0:80}"
      [[ ${#flat} -gt 80 ]] && preview+="…"
      echo "[$num] would write: $out"
      [[ -n "$voice" ]] && echo "       voice: $voice"
      echo "       text: $preview"
    else
      $QUIET || {
        echo "[$num] -> $out"
        [[ -n "$voice" ]] && echo "       voice: $voice"
      }
      if [[ -n "$voice" ]]; then
        "$TTS_CMD" -q -f wav -V "$voice" -o "$out" --text "$flat"
      else
        "$TTS_CMD" -q -f wav -o "$out" --text "$flat"
      fi
    fi
  fi

  index=$(( index + 1 ))
  count=$(( count + 1 ))
}

index=$START
count=0
para=""

# ---- Read file; handle directives, switches, and paragraphs ----
while IFS= read -r line || [[ -n "$line" ]]; do
  # Strip trailing CR (Windows)
  line=${line%$'\r'}

  # 1) Voice preset definition: "## name: expr"
  if [[ "$line" =~ ^[[:space:]]*##[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*:[[:space:]]*(.+)[[:space:]]*$ ]]; then
    name="${BASH_REMATCH[1]}"
    expr="${BASH_REMATCH[2]}"
    VOICE_PRESETS["$name"]="$expr"
    $QUIET || echo ">> preset defined: $name = $expr"
    continue
  fi

  # 2) Voice switch: "# name"
  if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*$ ]]; then
    # Finish any paragraph in progress before switching
    if [[ -n "$para" ]]; then
      emit_paragraph "$para" "$current_voice"
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

  # 3) Paragraph separator: blank line => emit accumulated paragraph
  if [[ "$line" =~ ^[[:space:]]*$ ]]; then
    if [[ -n "$para" ]]; then
      emit_paragraph "$para" "$current_voice"
      para=""
    fi
    continue
  fi

  # 4) Regular content line: accumulate into current paragraph
  if [[ -z "$para" ]]; then
    para="$line"
  else
    para+=$'\n'"$line"
  fi
done < "$FILE"

# Emit trailing paragraph (if file doesn't end with blank line)
[[ -n "$para" ]] && emit_paragraph "$para" "$current_voice"

if [[ "$count" -eq 0 ]]; then
  echo "No paragraphs found (file empty or only directives/blank lines)." >&2
  exit 0
fi

$QUIET || $DRY_RUN || echo "Done. Wrote $count file(s)."
