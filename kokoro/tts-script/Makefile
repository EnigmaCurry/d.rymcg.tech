READ   ?= ./read.sh
PLAY   ?= ./play.sh
OUTDIR ?= .
GAP_MS ?= 250

# Ensure these are visible to shell commands
export KOKORO_ENDPOINT
export KOKORO_API_KEY

.PHONY: help # Show this help screen
help:
	@printf '%s\n' \
'Usage (replace NAME with your .txt basename):' \
'  make NAME         - Render NAME.txt to .wav files (do not skip existing)' \
'  make NAME.play    - Render missing clips for NAME.txt and play in order' \
'  make NAME.clean   - Remove rendered audio files for NAME.txt' \
'' \
'Example targets already available:' \
'  make test1        - Render test1.txt' \
'  make test1.play   - Render missing clips for test1.txt and play in order' \
'  make test1.clean  - Remove rendered audio files for test1.txt' \
'' \
'To enable targets for another file (e.g., chapter1.txt), add this line to the Makefile:' \
'  $$(eval $$(call TTS_TARGETS,chapter1))' \
'' \
'Required environment:' \
'  KOKORO_ENDPOINT   - API endpoint' \
'  KOKORO_API_KEY    - API key' \
'Optional:' \
'  OUTDIR=./out      - Output directory' \
'  GAP_MS=250        - Gap (ms) between clips for *.play'


.PHONY: check-env # Verify KOKORO_* variables are set
check-env:
	@if [ -z "$$KOKORO_ENDPOINT" ]; then \
	  echo "ERROR: KOKORO_ENDPOINT is not set."; \
	  echo "  export KOKORO_ENDPOINT=\"https://kokoro.example.com/api/v1/audio/speech\""; \
	  exit 1; \
	fi
	@if [ -z "$$KOKORO_API_KEY" ]; then \
	  echo "ERROR: KOKORO_API_KEY is not set."; \
	  echo "  export KOKORO_API_KEY=\"<your-api-key>\""; \
	  exit 1; \
	fi


# -------- Reusable helper macro --------
# Usage: $(eval $(call TTS_TARGETS,<basename-without-.txt>))
define TTS_TARGETS
.PHONY: $(1) # Render $(1).txt to .wav files (do not skip existing)
$(1): check-env
	@mkdir -p "$(OUTDIR)"
	$(READ) -o "$(OUTDIR)" $(1).txt

.PHONY: $(1).play # Render missing clips and play them in order
$(1).play: check-env
	@mkdir -p "$(OUTDIR)"
	$(READ) --skip-existing -o "$(OUTDIR)" $(1).txt
	GAP_MS=$(GAP_MS) $(PLAY) -o "$(OUTDIR)" $(1).txt

.PHONY: $(1).clean # Remove rendered audio files for $(1).txt
$(1).clean:
	rm -f "$(OUTDIR)/$(1)-"*.wav
endef
# --------------------------------------

# Instantiate the trio for test1.txt
$(eval $(call TTS_TARGETS,test1))

# Add more projects by instantiating again, e.g.:
# $(eval $(call TTS_TARGETS,chapter1))
# $(eval $(call TTS_TARGETS,intro))
