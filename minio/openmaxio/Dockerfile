FROM python:3.11-slim
ARG OPENMAXIO_VERSION=v1.7.6
ENV POETRY_VERSION=1.8.2 \
    POETRY_HOME="/opt/poetry" \
    PATH="/opt/poetry/bin:/usr/local/go/bin:/usr/local/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
RUN apt-get update && \
    apt-get install --no-install-recommends -y curl git build-essential make xz-utils && \
    # Install Node.js
    curl -fsSL https://nodejs.org/dist/v18.20.2/node-v18.20.2-linux-x64.tar.xz | \
      tar -xJf - -C /usr/local --strip-components=1 && \
    # Enable corepack
    ln -s /usr/local/bin/corepack /usr/bin/corepack && \
    corepack enable && \
    # Install Go
    curl -fsSL https://go.dev/dl/go1.22.3.linux-amd64.tar.gz | \
      tar -C /usr/local -xzf - && \
    # Install Poetry
    curl -sSL https://install.python-poetry.org | python3 - --yes --preview && \
    poetry config virtualenvs.create false && \
    # Clean up
    apt-get clean && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN git clone --branch "${OPENMAXIO_VERSION}" --depth 1 https://github.com/OpenMaxIO/openmaxio-object-browser.git .
# Build the web frontend
WORKDIR /app/web-app
RUN yarn install && yarn build
# Build the Go backend
WORKDIR /app
RUN make console

CMD ["./console", "server"]
