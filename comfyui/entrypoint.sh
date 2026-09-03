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

# Workaround for ComfyUI-QwenTTS import failure with transformers >=4.57.
# The vendored qwen_tts code uses @check_model_inputs() with a signature that
# no longer matches transformers, which crashes the module load and leaves
# qwen_tts.core missing Qwen3TTSTokenizerV1Config.
# Upstream refs:
#   https://github.com/1038lab/ComfyUI-QwenTTS/issues/12
#   https://github.com/1038lab/ComfyUI-QwenTTS/issues/16
qwen_tts_dir="/ComfyUI/custom_nodes/ComfyUI-QwenTTS/qwen_tts"
if [ -d "${qwen_tts_dir}" ]; then
    find "${qwen_tts_dir}" -type f -name "*.py" -exec grep -lE '^[^#]*@check_model_inputs\(\)|^[^#]*from transformers\.utils\.generic import check_model_inputs' {} + 2>/dev/null | while read -r f; do
        echo "Patching ${f} (comment out @check_model_inputs)"
        sed -i \
            -e 's|^\([[:space:]]*\)@check_model_inputs()|\1# @check_model_inputs()  # patched: incompatible with transformers >=4.57|' \
            -e 's|^\([[:space:]]*\)from transformers\.utils\.generic import check_model_inputs|\1# from transformers.utils.generic import check_model_inputs  # patched|' \
            "${f}"
    done

    # Qwen3TTSTalkerConfig does not set pad_token_id in its __init__, so
    # `config.pad_token_id` raises AttributeError when Talker submodels are
    # constructed. Rewrite the two reads to fall back to None.
    # Upstream ref: https://github.com/1038lab/ComfyUI-QwenTTS/issues/10
    modeling_file="${qwen_tts_dir}/core/models/modeling_qwen3_tts.py"
    if [ -f "${modeling_file}" ] && grep -q 'self.padding_idx = config.pad_token_id' "${modeling_file}"; then
        echo "Patching ${modeling_file} (guard config.pad_token_id)"
        sed -i 's|self\.padding_idx = config\.pad_token_id|self.padding_idx = getattr(config, "pad_token_id", None)|g' "${modeling_file}"
    fi
fi

python3 main.py --multi-user --listen 0.0.0.0 --verbose "${LOG_LEVEL}"
