# README

## Overview

CLI tools to batch-generate and play TTS audio clips from `.txt` scripts:

* `read.sh` — renders **one WAV per paragraph** (blank-line–separated), 7-digit padded filenames.
* `play.sh` — renders missing clips (skip existing) **and plays them in order** with a configurable gap.
* `Makefile` — easy targets for any script name (e.g., `make test1`, `make chapter1.play`, …).

## Requirements

* Bash 4+
* `curl`, `jq`
* `sox` (SoX)
* A TTS endpoint + API key

## Environment (required)

Export these (used by `tts.sh` / `read.sh` / `play.sh` via `Makefile`):

```bash
export KOKORO_ENDPOINT="https://kokoro.example.com/api/v1/audio/speech"
export KOKORO_API_KEY="YOUR_API_KEY"
```

## Script format (input `.txt`)

* **Paragraphs** are blocks of non-empty lines separated by **blank lines**; each becomes one WAV.
* **Word Interpolation** can redefine words phonetically to be spoken correctly by the TTS engine.
  ```
  ## d.rymcg.tech=dee dot rye mcgee dot tech
  ```
* **Voice presets**:

  ```
  ## narrator: am_adam*0.5 + am_puck*0.3 + am_fenrir*0.1 + am_onyx*0.1
  ## person2:  af_heart*0.5 + af_alloy*0.5
  
* **Voice switches** (applies to following paragraphs):

  ```
  # narrator
  Once upon a time there were two people talking to each other.

  # heart_alloy
  What is your
  name?

  # aeode_river
  My name is aeode river.

  # narrator
  They became great friends as they struck up a conversation about d.rymcg.tech
  ```

## Output naming

For `script.txt`, files are:

```
script-0000001.wav
script-0000002.wav
...
```

(7-digit zero padding; order follows paragraph order.)

## Usage

### Direct scripts

```bash
# Render all paragraphs (do NOT skip existing)
./read.sh script.txt

# Render only missing clips and then play them with a 250 ms gap
GAP_MS=250 ./play.sh script.txt
```

Options:

* `read.sh`: `--skip-existing`, `-o OUTDIR`, `-s START`, `--dry-run`, `-q`
* `play.sh`: `--gap-ms N`, `-o OUTDIR`, `-q` (it calls `read.sh --skip-existing` automatically)

`read.sh` calls your TTS tool via `TTS_CMD` (defaults to `./tts.sh`). Pass endpoint/key via env; don’t put flags into `TTS_CMD`.

### Makefile targets (generic)

Use **NAME = basename of your .txt**:

* `make NAME` — render `NAME.txt` (do **not** skip existing)
* `make NAME.play` — render missing clips for `NAME.txt`, then play in order
* `make NAME.clean` — remove `NAME-*.wav`

Example already wired:

```bash
make test1
make test1.play
make test1.clean
```

Add more by instantiating the macro in `Makefile`:

```make
$(eval $(call TTS_TARGETS,chapter1))
$(eval $(call TTS_TARGETS,intro))
```

## Configuration knobs

* `OUTDIR` (Make/ENV): output directory (default: `.`)
* `GAP_MS` (Make/env or `--gap-ms`): gap between clips when playing (default: `250`)
* `TTS_CMD` (env): path to TTS client script (default: `./tts.sh`)

## Troubleshooting

* **“Missing API key/endpoint”** → ensure `KOKORO_ENDPOINT` and `KOKORO_API_KEY` are exported in your shell.
* **No audio player found** → install `mpv` (recommended) or `ffplay`/`play`/`aplay`.
* **Nothing renders** → ensure your `.txt` has **blank lines** between paragraphs; directives start with `##` (preset) or `#` (switch).
* **Voice not changing** → confirm the preset name in `# name` matches a prior `## name: ...` line.
