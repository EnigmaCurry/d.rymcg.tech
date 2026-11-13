#!/bin/bash
set -e

# /ComfyUI is a named volume, and Docker only copies the image's
# /ComfyUI into it the first time the volume is created. After that,
# rebuilding the image with a new COMFYUI_VERSION would not change the
# code that actually runs, so bring the volume up to the commit this
# image was built from.
IMAGE_COMMIT="$(cat /comfyui-image-commit 2>/dev/null || true)"
VOLUME_COMMIT="$(git -C /ComfyUI rev-parse HEAD 2>/dev/null || true)"
if [ -n "${IMAGE_COMMIT}" ] && [ "${IMAGE_COMMIT}" != "${VOLUME_COMMIT}" ]; then
    echo "Updating ComfyUI in volume from ${VOLUME_COMMIT:-unknown} to ${IMAGE_COMMIT} ..."
    if git -C /ComfyUI fetch --tags origin && \
       git -C /ComfyUI checkout --detach "${IMAGE_COMMIT}"; then
        python3 -m pip install -r /ComfyUI/requirements.txt
    else
        echo "WARNING: Could not update ComfyUI in volume, still running ${VOLUME_COMMIT:-unknown}" >&2
    fi
fi

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
# Skip on AMD/ROCm GPUs — flash-attn only supports NVIDIA CUDA
if python3 -c "import torch; assert torch.version.cuda is not None" 2>/dev/null; then
    if ! python3 -c "import flash_attn" 2>/dev/null; then
        echo "Installing flash-attn..."
        WHEEL_URL=$(python3 -c "
import sys, torch, urllib.parse
cuda = torch.version.cuda.replace('.','')
tv = torch.__version__.split('+')[0]
major_minor = '.'.join(tv.split('.')[:2])
cp = f'cp{sys.version_info.major}{sys.version_info.minor}'
name = f'flash_attn-2.8.3+cu{cuda}torch{major_minor}-{cp}-{cp}-linux_x86_64.whl'
print(f'https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.9.4/{urllib.parse.quote(name)}')
" 2>/dev/null)
        if [ -n "${WHEEL_URL}" ]; then
            echo "Trying prebuilt wheel: ${WHEEL_URL}"
            python3 -m pip install -q "${WHEEL_URL}" 2>/dev/null || \
                python3 -m pip install -q flash-attn --no-build-isolation 2>/dev/null || true
        fi
    fi
else
    echo "Skipping flash-attn (not supported on AMD/ROCm)"
fi

python3 main.py --multi-user --listen 0.0.0.0 --verbose "${LOG_LEVEL}"
