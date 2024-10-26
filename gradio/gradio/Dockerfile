FROM python:3.13-slim AS builder

ARG BUILD_PIPER=true

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
FROM python:3.13-slim
WORKDIR /app
ARG APP

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    espeak-ng libespeak-ng1 python3-pyaudio python3-pip portaudio19-dev \
    build-essential python3-dev curl procps && \
    rm -rf /var/lib/apt/lists/*

# Create a dummy pyaudioop package
RUN mkdir -p /tmp/pyaudioop && \
    echo "import audioop" > /tmp/pyaudioop/__init__.py && \
    echo "from setuptools import setup, find_packages; setup(name='pyaudioop', version='1.0', packages=find_packages())" > /tmp/pyaudioop/setup.py && \
    pip install /tmp/pyaudioop && \
    rm -rf /tmp/pyaudioop

COPY ${APP}/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN mkdir -p /app/piper_models

COPY --from=builder /piper/build/piper /usr/local/bin/
COPY --from=builder /piper/build/pi/lib/ /usr/local/lib/
COPY --from=builder /piper/build/pi/share/espeak-ng-data/ /usr/share/espeak-ng-data/
COPY --from=builder /build/piper_models /app/piper_models

COPY common.py ${APP}/ .

EXPOSE 7860

ENV PIPER_MODEL_DIR=/app/piper_models
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
ENV UVICORN_WORKERS=1
ENV MODE=gradio

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT /usr/local/bin/entrypoint.sh
