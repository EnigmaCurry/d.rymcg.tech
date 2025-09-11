FROM ubuntu:24.04
ARG COMFYUI_VERSION

WORKDIR /
COPY entrypoint.sh install-models.sh /
RUN chmod +x /entrypoint.sh /install-models.sh

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget git rsync dialog python3 python3-pip python3-venv ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --single-branch --branch ${COMFYUI_VERSION} https://github.com/comfyanonymous/ComfyUI.git

# Install ComfyUI Manager extension
WORKDIR /ComfyUI/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager comfyui-manager

WORKDIR /ComfyUI
RUN python3 -m venv .venv
ENV PATH="/ComfyUI/.venv/bin:$PATH"

# Install PyTorch for the requested GPU type
ARG GPU_TYPE
ARG ROCM_VERSION
ARG CUDA_WHEEL_VERSION
RUN case "${GPU_TYPE}" in \
    rocm)   groupadd -g 105 render && \
        __deb_file=$(curl -s "https://repo.radeon.com/amdgpu-install/${ROCM_VERSION}/ubuntu/noble/" |  grep -oP '<a href="\K[^"]+\.deb' | head -n1) && \
       : "${__deb_file:-amdgpu-install_6.4.60403-1_all.deb}" && \
        wget -q https://repo.radeon.com/amdgpu-install/${ROCM_VERSION}/ubuntu/noble/${__deb_file} && \
        apt-get install ./${__deb_file} && \
        apt-get install -y python3-setuptools python3-wheel && \
        apt-get update && \
        apt-get install -y rocm && \
        rm -rf /var/lib/apt/lists/* && \
        python3 -m pip install --upgrade pip && \
        bash -c 'SHORT_VERSION="${ROCM_VERSION%%.*.*}"; \
        if [[ "$ROCM_VERSION" == *.*.* ]]; then \
          SECOND="${ROCM_VERSION#*.}"; \
          SECOND="${SECOND%%.*}"; \
          SHORT_VERSION="$SHORT_VERSION.$SECOND"; \
        fi; \
        python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm${SHORT_VERSION}' ;; \
    intel)  python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/xpu ;; \
    cuda)   python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/${CUDA_WHEEL_VERSION} ;; \
    cpu)    python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu ;; \
    *)      echo "Unknown GPU type: ${GPU_TYPE}\n" && exit 1 ;; \
    esac

RUN python3 -m pip install -r requirements.txt

ARG HSA_OVERRIDE_GFX_VERSION
ENV HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION}
ARG LOG_LEVEL
ENV LOG_LEVEL=${LOG_LEVEL}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["python3", "main.py", "--multi-user", "--listen 0.0.0.0", "--verbose", "${LOG_LEVEL}"]
