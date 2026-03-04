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
    inotify-tools \
    gettext-envsubst \
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

# Create non-root user
RUN adduser -D -u 1000 -h /home/user -s /bin/bash user \
 && mkdir -p /run/secrets/ssh \
 && chown -R 1000:1000 /home/user /run/secrets/ssh

ENV PATH="/home/user/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user:/home/user/.local/bin:/usr/local/bin:${PATH}"
ENV HOME="/home/user"
COPY --chown=1000:1000 _container/bashrc /home/user/.bashrc

# Seed uv-managed Python (cached early, only depends on uv + user home)
USER user
RUN uv python install --no-cache
USER root

# Copy the d.rymcg.tech repo, optionally switch branch, then strip history
ARG BRANCH=
ARG IMAGE_SOURCE=
ARG IMAGE_REF=localhost/d-rymcg-tech:latest
COPY --chown=1000:1000 . /home/user/git/vendor/enigmacurry/d.rymcg.tech
WORKDIR /home/user/git/vendor/enigmacurry/d.rymcg.tech
RUN if [ -n "${BRANCH}" ] && [ -d .git ]; then git checkout "${BRANCH}"; fi && rm -rf .git

# Install script-wizard from .tools.lock.json
RUN set -e; \
    VERSION=$(jq -r '.dependencies["script-wizard"].version' .tools.lock.json); \
    case "$(uname -m)" in \
      x86_64)  ARCH=x86_64 ;; \
      aarch64) ARCH=aarch64 ;; \
      *)       echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/EnigmaCurry/script-wizard/releases/download/v${VERSION}/script-wizard-Linux-${ARCH}.tar.gz" \
      | tar xz -C _scripts; \
    ln -s ../script-wizard _scripts/user/script-wizard

COPY --chown=1000:1000 _container/drt /usr/local/bin/drt
RUN chmod +x /usr/local/bin/drt

COPY --chown=1000:1000 _container/sign-ssh-cert /usr/local/bin/sign-ssh-cert
RUN chmod +x /usr/local/bin/sign-ssh-cert

COPY --chown=1000:1000 _container/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER user

ENV DRT_IMAGE=${IMAGE_REF}
LABEL org.opencontainers.image.source=${IMAGE_SOURCE}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
