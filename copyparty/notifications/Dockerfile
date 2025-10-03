# syntax=docker/dockerfile:1.7
ARG PYTHON_VERSION=3.12

# --- Builder: install uv and resolve deps ---
FROM python:${PYTHON_VERSION}-slim AS builder
ARG TARGETARCH
ENV UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=.venv \
    PATH="/root/.local/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates build-essential && rm -rf /var/lib/apt/lists/*
# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

# Add source and re-sync (fast since deps are cached)
COPY src ./src
RUN uv sync --frozen --no-dev

# --- Runtime: copy venv + app into a skinny image ---
FROM python:${PYTHON_VERSION}-slim AS runtime
ARG USER_UID=10001
ARG USER_GID=10001

# Minimal runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends tini && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN groupadd -g ${USER_GID} appuser && useradd -m -u ${USER_UID} -g ${USER_GID} -s /usr/sbin/nologin appuser

WORKDIR /app
COPY --from=builder /app/.venv ./.venv
COPY --from=builder /app/src ./src

ENV PATH="/app/.venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1

USER appuser
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["python","-m","copyparty_notifications"]
