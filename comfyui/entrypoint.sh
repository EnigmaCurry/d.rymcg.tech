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

# Workarounds for ComfyUI-QwenTTS with modern transformers. The vendored
# qwen_tts code has three known bugs; all patches are idempotent.
# Upstream refs:
#   https://github.com/1038lab/ComfyUI-QwenTTS/issues/10  (pad_token_id)
#   https://github.com/1038lab/ComfyUI-QwenTTS/issues/12  (check_model_inputs)
#   https://github.com/1038lab/ComfyUI-QwenTTS/issues/16  (ROPE_INIT_FUNCTIONS)
#   https://github.com/QwenLM/Qwen3-TTS/pull/201         (upstream fix)
qwen_tts_dir="/ComfyUI/custom_nodes/ComfyUI-QwenTTS/qwen_tts"
if [ -d "${qwen_tts_dir}" ]; then
    # (1) @check_model_inputs() signature mismatch — comment out the decorator
    #     and its import in any tokenizer file that uses it.
    find "${qwen_tts_dir}" -type f -name "*.py" -exec grep -lE '^[^#]*@check_model_inputs\(\)|^[^#]*from transformers\.utils\.generic import check_model_inputs' {} + 2>/dev/null | while read -r f; do
        echo "Patching ${f} (comment out @check_model_inputs)"
        sed -i \
            -e 's|^\([[:space:]]*\)@check_model_inputs()|\1# @check_model_inputs()  # patched: incompatible with transformers >=4.57|' \
            -e 's|^\([[:space:]]*\)from transformers\.utils\.generic import check_model_inputs|\1# from transformers.utils.generic import check_model_inputs  # patched|' \
            "${f}"
    done

    # (2) fix_mistral_regex is a kwarg only recognized by transformers >=4.57.
    #     Older versions raise TypeError on unknown kwargs; newer versions have
    #     a buggy implementation. Strip the argument entirely — Qwen doesn't
    #     need Mistral-specific tokenizer fixes.
    inference_file="${qwen_tts_dir}/inference/qwen3_tts_model.py"
    if [ -f "${inference_file}" ] && grep -qE 'fix_mistral_regex\s*=' "${inference_file}"; then
        echo "Patching ${inference_file} (strip fix_mistral_regex kwarg)"
        sed -i -E 's|,?\s*fix_mistral_regex\s*=\s*(True|False)\s*,?||g' "${inference_file}"
    fi

    # (3) config.pad_token_id read errors and (4) missing ROPE 'default' key:
    #     apply per PR #201 semantics via a Python patcher.
    python3 - "${qwen_tts_dir}/core/models/modeling_qwen3_tts.py" <<'PYEOF'
import re, sys
from pathlib import Path

f = Path(sys.argv[1])
if not f.exists():
    sys.exit(0)

src = f.read_text()
orig = src
marker = "# --- QWEN_TTS_PATCH: rope default + padding_idx ---"

if marker not in src:
    patch = f'''{marker}
try:
    from transformers.modeling_rope_utils import ROPE_INIT_FUNCTIONS
    import torch as _qtts_torch
    if "default" not in ROPE_INIT_FUNCTIONS:
        def _qtts_default_rope(config, device, seq_len=None, layer_type=None):
            base = getattr(config, "rope_theta", 10000)
            prf = getattr(config, "partial_rotary_factor", 1.0)
            head_dim = getattr(config, "head_dim", None)
            if head_dim is None:
                head_dim = getattr(config, "hidden_size", 4096) // getattr(config, "num_attention_heads", 32)
            dim = int(head_dim * prf)
            inv_freq = 1.0 / (base ** (_qtts_torch.arange(0, dim, 2, dtype=_qtts_torch.int64).to(device=device, dtype=_qtts_torch.float) / dim))
            return inv_freq, 1.0
        ROPE_INIT_FUNCTIONS["default"] = _qtts_default_rope
except Exception:
    pass

'''
    src = patch + src

# Restrict padding_idx substitutions to each class's own scope so we don't
# mix them up. Matches both the original assignment and any prior getattr
# workaround.
def rewrite_padding(src, class_name, replacement):
    return re.sub(
        r'(class ' + re.escape(class_name) + r'\b.*?self\.padding_idx\s*=\s*)[^\n]+',
        lambda m: m.group(1) + replacement,
        src, count=1, flags=re.DOTALL,
    )

src = rewrite_padding(src, "Qwen3TTSTalkerCodePredictorModel", "config.vocab_size - 1")
src = rewrite_padding(src, "Qwen3TTSTalkerModel", "config.codec_pad_id")

if src != orig:
    f.write_text(src)
    print(f"Patched {f} (ROPE default + padding_idx per PR #201)")
PYEOF
fi

python3 main.py --multi-user --listen 0.0.0.0 --verbose "${LOG_LEVEL}"
