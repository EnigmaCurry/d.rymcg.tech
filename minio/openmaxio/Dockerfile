FROM python:3.11-slim
ARG OPENMAXIO_VERSION=v2.0.1
ENV POETRY_VERSION=1.8.2 \
    POETRY_HOME="/opt/poetry" \
    PATH="/opt/poetry/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/usr/local/go/bin:$PATH"
RUN apt-get update && \
    apt-get install -y curl git build-essential make xz-utils && \
    curl -fsSL https://nodejs.org/dist/v18.20.2/node-v18.20.2-linux-x64.tar.xz | tar -xJf - -C /usr/local --strip-components=1 && \
    curl -fsSL https://go.dev/dl/go1.22.3.linux-amd64.tar.gz | tar -C /usr/local -xzf - && \
    export PATH=$PATH:/usr/local/go/bin && \
    ln -s /usr/local/bin/corepack /usr/bin/corepack && \
    corepack enable && \
    curl -sSL https://install.python-poetry.org | python3 - && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://nodejs.org/dist/v18.20.2/node-v18.20.2-linux-x64.tar.xz | tar -xJf - -C /usr/local --strip-components=1 && \
    ln -sf /usr/local/bin/node /usr/bin/node && \
    ln -sf /usr/local/bin/npm /usr/bin/npm && \
    ln -sf /usr/local/bin/corepack /usr/bin/corepack && \
    ln -sf /usr/local/bin/yarn /usr/bin/yarn && \
    corepack enable
WORKDIR /app
RUN git clone --branch "${OPENMAXIO_VERSION}" https://github.com/OpenMaxIO/openmaxio-object-browser.git .
WORKDIR /app/web-app
RUN yarn install && yarn build
WORKDIR /app
RUN make console
CMD ["./console", "server"]
