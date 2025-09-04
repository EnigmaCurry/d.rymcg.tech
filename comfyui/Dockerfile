FROM ubuntu:24.04
ARG COMFYUI_VERSION=v0.3.57

WORKDIR /
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget git rsync dialog python3 python3-pip python3-venv ca-certificates && \
    rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --single-branch --branch ${COMFYUI_VERSION} https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /ComfyUI
RUN python3 -m venv .venv
ENV PATH="/ComfyUI/.venv/bin:$PATH"

# Install PyTorch for the requested GPU type
ARG GPU_TYPE=cuda
RUN case "${GPU_TYPE}" in \
    rocm)   groupadd -g 105 render && \
        wget -q https://repo.radeon.com/amdgpu-install/6.4.3/ubuntu/noble/amdgpu-install_6.4.60403-1_all.deb && \
        apt-get install ./amdgpu-install_6.4.60403-1_all.deb && \
        apt-get install -y python3-setuptools python3-wheel && \
        apt-get update && \
        apt-get install -y rocm && \
        rm -rf /var/libat/lists/* && \
        python3 -m pip install --upgrade pip && \
        python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.4 ;; \
    intel)  python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/xpu ;; \
    cuda)   python3 -m pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu129 ;; \
    cpu)    python3 -m pip install torch torchvision torchaudio ;; \
    *)      echo "Unknown GPU type: ${GPU_TYPE}\n" && exit 1 ;; \
    esac

RUN python3 -m pip install -r requirements.txt

ARG HSA_OVERRIDE_GFX_VERSION=""
ENV HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION}
ARG LOG_LEVEL=WARNING
ENV LOG_LEVEL=${LOG_LEVEL}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["python3", "main.py", "--multi-user", "--listen 0.0.0.0", "--verbose", "${LOG_LEVEL}"]
