# syntax=docker/dockerfile:1.4

#### Web UI ------------------------------------

FROM docker.io/node:22-slim AS web-builder
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack use pnpm@10.x && corepack enable

ARG VERSION
WORKDIR /repo-tmp
RUN apt update && \
    apt install -y --no-install-recommends git apt-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --filter=blob:none --no-checkout https://github.com/invoke-ai/InvokeAI.git && \
    cd InvokeAI && \
    git sparse-checkout set 'invokeai/' && \
    git fetch origin tag ${VERSION} && \
    git checkout ${VERSION}

WORKDIR /build
RUN cp -r /repo-tmp/InvokeAI/invokeai/frontend/web/* ./
RUN --mount=type=cache,target=/pnpm/store \
    pnpm install --frozen-lockfile
RUN npx vite build

## Backend ---------------------------------------

FROM library/ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt update && apt install -y --no-install-recommends \
    ca-certificates \
    git \
    gosu \
    libglib2.0-0 \
    libgl1 \
    libglx-mesa0 \
    build-essential \
    libopencv-dev \
    libstdc++-10-dev \
    wget

ENV \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    VIRTUAL_ENV=/opt/venv \
    INVOKEAI_SRC=/opt/invokeai \
    PYTHON_VERSION=3.12 \
    UV_PYTHON=3.12 \
    UV_COMPILE_BYTECODE=1 \
    UV_MANAGED_PYTHON=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    INVOKEAI_ROOT=/invokeai \
    INVOKEAI_HOST=0.0.0.0 \
    INVOKEAI_PORT=9090 \
    PATH="/opt/venv/bin:$PATH" \
    CONTAINER_UID=${CONTAINER_UID:-1000} \
    CONTAINER_GID=${CONTAINER_GID:-1000}

ARG GPU_DRIVER=cuda

# Install `uv` for package management
COPY --from=ghcr.io/astral-sh/uv:0.6.9 /uv /uvx /bin/

# Install python & allow non-root user to use it by traversing the /root dir without read permissions
RUN --mount=type=cache,target=/root/.cache/uv \
    uv python install ${PYTHON_VERSION} && \
    # chmod --recursive a+rX /root/.local/share/uv/python
    chmod 711 /root

WORKDIR ${INVOKEAI_SRC}

# Install project's dependencies as a separate layer so they aren't rebuilt every commit.
#
# NOTE: there are no pytorch builds for arm64 + cuda, only cpu
# x86_64/CUDA is the default
COPY --from=web-builder /repo-tmp/InvokeAI/pyproject.toml .
COPY --from=web-builder /repo-tmp/InvokeAI/uv.lock .
COPY --from=web-builder /repo-tmp/InvokeAI/invokeai/version ./invokeai/version
RUN --mount=type=cache,target=/root/.cache/uv \
    ulimit -n 30000 && \
    uv sync --extra $GPU_DRIVER --frozen

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    if [ "$GPU_DRIVER" = "rocm" ]; then \
    wget -O /tmp/amdgpu-install.deb \
    https://repo.radeon.com/amdgpu-install/6.3.4/ubuntu/noble/amdgpu-install_6.3.60304-1_all.deb && \
    apt install -y /tmp/amdgpu-install.deb && \
    apt update && \
    amdgpu-install --usecase=rocm -y && \
    apt-get autoclean && \
    apt clean && \
    rm -rf /tmp/* /var/tmp/* && \
    usermod -a -G render ubuntu && \
    usermod -a -G video ubuntu && \
    echo "\\n/opt/rocm/lib\\n/opt/rocm/lib64" >> /etc/ld.so.conf.d/rocm.conf && \
    ldconfig && \
    update-alternatives --auto rocm; \
    fi

# # Link amdgpu.ids for ROCm builds
# # contributed by https://github.com/Rubonnek
# RUN mkdir -p "/opt/amdgpu/share/libdrm" &&\
#     ln -s "/usr/share/libdrm/amdgpu.ids" "/opt/amdgpu/share/libdrm/amdgpu.ids" && groupadd render

# build patchmatch
RUN cd /usr/lib/$(uname -p)-linux-gnu/pkgconfig/ && ln -sf opencv4.pc opencv.pc
RUN python -c "from patchmatch import patch_match"

RUN mkdir -p ${INVOKEAI_ROOT} && chown -R ${CONTAINER_UID}:${CONTAINER_GID} ${INVOKEAI_ROOT}

COPY ./docker-entrypoint.sh ./
ENTRYPOINT ["/opt/invokeai/docker-entrypoint.sh"]
CMD ["invokeai-web"]

# --link requires buldkit w/ dockerfile syntax 1.4, does not work with podman
COPY --link --from=web-builder /build/dist ${INVOKEAI_SRC}/invokeai/frontend/web/dist

# add sources last to minimize image changes on code changes
COPY --from=web-builder /repo-tmp/InvokeAI/invokeai ${INVOKEAI_SRC}/invokeai

# this should not increase image size because we've already installed dependencies
# in a previous layer
COPY --from=web-builder /repo-tmp/InvokeAI/pyproject.toml .
COPY --from=web-builder /repo-tmp/InvokeAI/uv.lock .
RUN --mount=type=cache,target=/root/.cache/uv \
    ulimit -n 30000 && \
    uv pip install -e .[$GPU_DRIVER]
