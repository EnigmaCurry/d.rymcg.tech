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
read.sh - Generate one WAV per *paragraph* and support voice + interpolation directives.

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

# ---- Directive storage ----
# Voice presets: name -> voice expression
declare -A VOICE_PRESETS=()
current_voice=""

# Interpolations: key -> value
declare -A INTERP_MAP=()
# Keep definition order for deterministic application
INTERP_KEYS=()

# ---- Helpers ----

# Apply paragraph flattening and interpolations
flatten_and_interpolate() {
  local raw="$1"
  # 1) Flatten: join wrapped lines into one line and normalize spaces
  local flat
  flat=$(printf '%s' "$raw" \
    | tr '\n' ' ' \
    | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$$//')

  # 2) Interpolate: replace each key with its value
  #    Apply in definition order (you can adjust if you prefer longest-first).
  local out="$flat"
  local key val pat
  for key in "${INTERP_KEYS[@]}"; do
    val="${INTERP_MAP[$key]}"
    # Escape glob chars in key for bash pattern substitution
    pat="${key//\\/\\\\}"   # backslash -> \\ (safeguard)
    pat="${pat//\*/\\*}"    # * -> \*
    pat="${pat//\?/\\?}"    # ? -> \?
    pat="${pat//[/\\[}"     # [ -> \[
    out="${out//"$pat"/$val}"
  done
  printf '%s' "$out"
}

emit_paragraph() {
  local text="$1"
  local voice="$2"
  [[ -z "$text" ]] && return 0

  local final
  final="$(flatten_and_interpolate "$text")"

  local num out
  num=$(printf "%07d" "$index")
  out="$OUTDIR/${prefix}-${num}.wav"

  if $SKIP_EXISTING && [[ -s "$out" ]]; then
    $QUIET || echo "[$num] exists, skipping: $out"
  else
    if $DRY_RUN; then
      local preview="${final:0:80}"; [[ ${#final} -gt 80 ]] && preview+="…"
      echo "[$num] would write: $out"
      [[ -n "$voice" ]] && echo "       voice: $voice"
      echo "       text: $preview"
    else
      $QUIET || {
        echo "[$num] -> $out"
        [[ -n "$voice" ]] && echo "       voice: $voice"
      }
      if [[ -n "$voice" ]]; then
        "$TTS_CMD" -q -f wav -V "$voice" -o "$out" --text "$final"
      else
        "$TTS_CMD" -q -f wav -o "$out" --text "$final"
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
  line=${line%$'\r'}  # strip trailing CR (Windows)

  # Voice preset definition: "## name: expr"
  if [[ "$line" =~ ^[[:space:]]*##[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*:[[:space:]]*(.+)[[:space:]]*$ ]]; then
    name="${BASH_REMATCH[1]}"
    expr="${BASH_REMATCH[2]}"
    VOICE_PRESETS["$name"]="$expr"
    $QUIET || echo ">> preset defined: $name = $expr"
    continue
  fi

  # Interpolation definition: "## key=value"
  if [[ "$line" =~ ^[[:space:]]*##[[:space:]]*([^=[:space:]][^=]*)[[:space:]]*=[[:space:]]*(.+)[[:space:]]*$ ]]; then
    key="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"
    # Trim outer spaces (already mostly done by regex)
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

  # Paragraph separator: blank line => emit accumulated paragraph
  if [[ "$line" =~ ^[[:space:]]*$ ]]; then
    if [[ -n "$para" ]]; then
      emit_paragraph "$para" "$current_voice"
      para=""
    fi
    continue
  fi

  # Regular content line: accumulate into current paragraph
  if [[ -z "$para" ]]; then
    para="$line"
  else
    para+=$'\n'"$line"
  fi
done < "$FILE"

# Emit trailing paragraph if file didn't end with a blank line
[[ -n "$para" ]] && emit_paragraph "$para" "$current_voice"

if [[ "$count" -eq 0 ]]; then
  echo "No paragraphs found (file empty or only directives/blank lines)." >&2
  exit 0
fi

$QUIET || $DRY_RUN || echo "Done. Wrote $count file(s)."
