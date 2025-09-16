# Stage 1: Build Piper and download voice model (optional based on an ARG)
FROM python:3.9-slim AS piper

# Argument to determine whether to build Piper
ARG BUILD_PIPER=true

# Install dependencies, including espeak-ng and CMake for Piper
RUN if [ "$BUILD_PIPER" = "true" ]; then \
        apt-get update && \
        apt-get install -y --no-install-recommends \
        build-essential \
        libsndfile1-dev \
        cmake \
        git \
        curl \
        ca-certificates \
        espeak-ng \
        libespeak-ng-dev && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Clone, build, and install Piper
RUN if [ "$BUILD_PIPER" = "true" ]; then \
        git clone https://github.com/rhasspy/piper.git && \
        cd piper && \
        mkdir build && \
        cd build && \
        cmake .. && \
        make && \
        make install && \
        ls /usr/local/bin && \
        mkdir -p /build/piper_models; \
    fi

ARG MODEL_URLS=https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/low/en_US-amy-low.onnx,https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/danny/low/en_US-danny-low.onnx,https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/john/medium/en_US-john-medium.onnx,https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx

RUN if [ "$BUILD_PIPER" = "true" ]; then \
    IFS=','; \
    for url in $MODEL_URLS; do \
        model_name=$(basename "$url"); \
        echo "Downloading model: $model_name"; \
        curl -L -o /build/piper_models/$model_name $url; \
        curl -L -o /build/piper_models/$model_name.json $url.json; \
    done; \
    fi


# Stage 2: Final runtime image
FROM nvidia/cuda:13.0.1-cudnn-runtime-ubuntu24.04

# Set working directory
WORKDIR /app
ARG APP

# Install espeak-ng runtime libraries needed for Piper to work
RUN apt-get update && apt-get install -y --no-install-recommends espeak-ng libespeak-ng1 && rm -rf /var/lib/apt/lists/*

# Install uv CLI
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Copy only project metadata first for better Docker layer caching
COPY ${APP}/pyproject.toml ./pyproject.toml
# If you have a lock file, copy it too for reproducible builds
COPY ${APP}/uv.lock ./uv.lock
COPY ${APP}/README.md ./README.md
COPY ${APP}/LICENSE ./LICENSE

# Use system site-packages (keeps image small and avoids venv activation)
# --frozen requires uv.lock to match; remove --frozen if you don't check in uv.lock
RUN uv sync --frozen --no-dev
ENV VIRTUAL_ENV=/app/.venv
ENV PATH="/app/.venv/bin:${PATH}"

# Create Piper model directory (even if not used) to avoid COPY errors
RUN mkdir -p /app/piper_models

# Conditionally copy Piper binary and models if they were built
COPY --from=piper /piper/build/piper /usr/local/bin/
COPY --from=piper /piper/build/pi/lib/ /usr/local/lib/
COPY --from=piper /piper/build/pi/share/espeak-ng-data/ /usr/share/espeak-ng-data/
COPY --from=piper /build/piper_models /app/piper_models

# Copy the application code after deps to maximize cache hits
COPY common.py ${APP}/ .

# Expose the application port
EXPOSE 7860

# Piper env (only used if Piper is present)
ENV PIPER_MODEL_DIR=/app/piper_models
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

ENV GRADIO_SERVER_PORT=7860
ENV GRADIO_SERVER_NAME=0.0.0.0

# Run the app
CMD ["uv", "run", "main.py"]
