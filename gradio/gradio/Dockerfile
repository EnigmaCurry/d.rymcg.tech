# Stage 1: Build Piper and download voice model (optional based on an ARG)
FROM python:3.9-slim AS builder

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

ARG MODEL_URL=https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/low/en_US-amy-low.onnx
RUN if [ "$BUILD_PIPER" = "true" ]; then \
        curl -L -o /build/piper_models/$(echo ${MODEL_URL} | xargs basename) ${MODEL_URL}; \
        curl -L -o /build/piper_models/$(echo ${MODEL_URL} | xargs basename).json ${MODEL_URL}.json; \
    fi

# Stage 2: Final runtime image
FROM python:3.9-slim

# Set working directory
WORKDIR /app
ARG APP

# Install espeak-ng runtime libraries needed for Piper to work
RUN apt-get update && apt-get install -y --no-install-recommends espeak-ng libespeak-ng1 && rm -rf /var/lib/apt/lists/*

# Copy the requirements and install Python dependencies
COPY ${APP}/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create Piper model directory (even if not used) to avoid COPY errors
RUN mkdir -p /app/piper_models

# Conditionally copy Piper binary and models if they were built
COPY --from=builder /piper/build/piper /usr/local/bin/
COPY --from=builder /piper/build/pi/lib/ /usr/local/lib/
COPY --from=builder /piper/build/pi/share/espeak-ng-data/ /usr/share/espeak-ng-data/
COPY --from=builder /build/piper_models /app/piper_models

# Copy the application code
COPY common.py ${APP}/ .

# Expose the application port
EXPOSE 7860

# Set environment variable for Piper model directory (only used if Piper is built)
ENV PIPER_MODEL_DIR=/app/piper_models
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Command to run the application
CMD ["python", "main.py"]
