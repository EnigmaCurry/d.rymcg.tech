#!/bin/bash
set -e

if [ -n "$COMFYUI_OUTPUT_HOST_PATH" ]; then
    mkdir -p "/ComfyUI/models/audio_encoders" \
          "/ComfyUI/models/checkpoints" \
          "/ComfyUI/models/clip" \
          "/ComfyUI/models/clip_vision" \
          "/ComfyUI/models/configs" \
          "/ComfyUI/models/controlnet" \
          "/ComfyUI/models/diffusers" \
          "/ComfyUI/models/diffusion_models" \
          "/ComfyUI/models/embeddings" \
          "/ComfyUI/models/gligen" \
          "/ComfyUI/models/hypernetworks" \
          "/ComfyUI/models/latent_upscale_models" \
          "/ComfyUI/models/loras" \
          "/ComfyUI/models/model_patches" \
          "/ComfyUI/models/photomaker" \
          "/ComfyUI/models/style_models" \
          "/ComfyUI/models/text_encoders" \
          "/ComfyUI/models/unet" \
          "/ComfyUI/models/upscale_models" \
          "/ComfyUI/models/vae" \
          "/ComfyUI/models/vae_approx"
fi

if [ -n "${HSA_OVERRIDE_GFX_VERSION}" ]; then
    export HSA_OVERRIDE_GFX_VERSION="${HSA_OVERRIDE_GFX_VERSION}"
fi

: ${LOG_LEVEL:=WARNING}

# Install flash-attn if not already present (needed by SeedVR2, transformers)
if ! python3 -c "import flash_attn" 2>/dev/null; then
    echo "Installing flash-attn..."
    python3 -m pip install -q flash-attn 2>/dev/null || true
fi

python3 main.py --multi-user --listen 0.0.0.0 --verbose "${LOG_LEVEL}"
