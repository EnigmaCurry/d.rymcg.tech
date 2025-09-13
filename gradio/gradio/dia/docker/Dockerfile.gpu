# Dockerfile.gpu - GPU deployment for DIA
# --------------------------------------------------
# Build: docker build . -f docker/Dockerfile.gpu -t dia-gpu
# Run:   docker run --rm --gpus all -p 7860:7860 dia-gpu
# Requires NVIDIA Container Toolkit on host.

FROM pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime

# Set non-interactive frontend
ENV DEBIAN_FRONTEND=noninteractive

# Install venv, and system dependencies
RUN apt-get update && apt-get install -y \
    python3-venv \
    libsndfile1 \
    ffmpeg \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user and set up directories
RUN useradd -m -u 1001 appuser && \
    mkdir -p /app/outputs /app && \
    chown -R appuser:appuser /app

USER appuser
WORKDIR /app

# Copy all code (including pyproject.toml)
COPY --chown=appuser:appuser . .

# Create and activate virtual environment
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Install all project dependencies
RUN pip install --upgrade pip && pip install --no-cache-dir .

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    USE_GPU=true \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda-12.1/lib64:${LD_LIBRARY_PATH}

# Expose Gradio default port
ENV GRADIO_SERVER_NAME="0.0.0.0"
EXPOSE 7860

# Entrypoint
CMD ["python3", "app.py"]
