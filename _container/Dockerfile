# Build context must be the d.rymcg.tech root directory.
# Build with: docker build -f _container/Dockerfile -t d-rymcg-tech .

FROM alpine:3.23

# Install all runtime packages from Alpine repos
RUN apk add --no-cache \
    bash \
    make \
    git \
    openssl \
    apache2-utils \
    jq \
    curl \
    moreutils \
    inotify-tools \
    gettext \
    ipcalc \
    openssh-client \
    docker-cli \
    docker-cli-compose \
    sops \
    age \
    ca-certificates \
    tar \
    gzip \
    coreutils \
    findutils \
    grep \
    sed \
    gawk \
    gcompat \
    libgcc

# Install uv (Python package manager)
RUN curl -fsSL https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh

# Install script-wizard from .tools.lock.json
COPY .tools.lock.json /tmp/.tools.lock.json
RUN set -e; \
    VERSION=$(jq -r '.dependencies["script-wizard"].version' /tmp/.tools.lock.json); \
    case "$(uname -m)" in \
      x86_64)  ARCH=x86_64 ;; \
      aarch64) ARCH=aarch64 ;; \
      *)       echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/EnigmaCurry/script-wizard/releases/download/v${VERSION}/script-wizard-Linux-${ARCH}.tar.gz" \
      | tar xz -C /usr/local/bin; \
    rm /tmp/.tools.lock.json

# Create non-root user
RUN adduser -D -u 1000 -h /home/user -s /bin/bash user \
 && mkdir -p /run/secrets/ssh \
 && chown -R 1000:1000 /home/user /run/secrets/ssh

ENV PATH="/home/user/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user:/home/user/.local/bin:/usr/local/bin:${PATH}"
ENV HOME="/home/user"
RUN printf '%s\n' \
  'PS1="\n[d.rymcg.tech|$DOCKER_CONTEXT] \w\n\$ "' \
  'eval "$(d.rymcg.tech completion bash)"' \
  '__d.rymcg.tech_cli_alias d' \
  '[ -n "$DOCKER_CONTEXT" ] && __d.rymcg.tech_context_alias $DOCKER_CONTEXT' \
  > /home/user/.bashrc \
 && chown 1000:1000 /home/user/.bashrc

# Copy the d.rymcg.tech repo, optionally switch branch, then strip history
ARG BRANCH=
ARG IMAGE_SOURCE=
COPY --chown=1000:1000 . /home/user/git/vendor/enigmacurry/d.rymcg.tech
WORKDIR /home/user/git/vendor/enigmacurry/d.rymcg.tech
RUN if [ -n "${BRANCH}" ] && [ -d .git ]; then git checkout "${BRANCH}"; fi && rm -rf .git

COPY --chown=1000:1000 _container/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER user
# Seed uv-managed Python into user's home
RUN uv python install --no-cache

LABEL org.opencontainers.image.source=${IMAGE_SOURCE}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
