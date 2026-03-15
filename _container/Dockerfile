# Build context must be the d.rymcg.tech root directory.
# Build with: docker build -f _container/Dockerfile -t d-rymcg-tech .

# Build age-plugin-fido2-hmac from source (supports all architectures)
FROM docker.io/library/golang:1.24-alpine AS fido2-builder
COPY .tools.lock.json /tmp/.tools.lock.json
RUN apk add --no-cache git jq gcc musl-dev libfido2-dev && \
    VERSION=$(jq -r '.dependencies["age-plugin-fido2-hmac"].version' /tmp/.tools.lock.json) && \
    git clone https://github.com/olastor/age-plugin-fido2-hmac.git /src && \
    cd /src && git -c advice.detachedHead=false checkout "v${VERSION}" && \
    CGO_ENABLED=1 go build -o /age-plugin-fido2-hmac ./cmd/age-plugin-fido2-hmac

FROM docker.io/library/alpine:3.23

# Copy age-plugin-fido2-hmac from builder
COPY --from=fido2-builder /age-plugin-fido2-hmac /usr/local/bin/age-plugin-fido2-hmac

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
    docker-cli-buildx \
    docker-cli-compose \
    sops \
    age \
    libfido2 \
    ca-certificates \
    tar \
    gzip \
    coreutils \
    findutils \
    grep \
    sed \
    gawk \
    nano \
    mg \
    gcompat \
    libgcc \
    su-exec \
    util-linux \
    bash-completion

# Install uv (Python package manager)
RUN curl -fsSL https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh

# Install doctl (DigitalOcean CLI)
RUN set -e; \
    case "$(uname -m)" in \
      x86_64)  ARCH=amd64 ;; \
      aarch64) ARCH=arm64 ;; \
      *)       echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    DOCTL_VERSION=$(curl -sf https://api.github.com/repos/digitalocean/doctl/releases/latest | jq -r .tag_name | sed 's/^v//'); \
    curl -fsSL "https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-${ARCH}.tar.gz" \
      | tar xz -C /usr/local/bin

# Create non-root user
RUN adduser -D -u 1000 -h /home/user -s /bin/bash user \
 && mkdir -p /run/secrets/ssh /home/user/.config/d.rymcg.tech \
 && chown -R 1000:1000 /home/user /run/secrets/ssh

ENV UV_PROJECT_ENVIRONMENT="/home/user/.venv"
ENV PATH="/home/user/.venv/bin:/home/user/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user:/home/user/.local/bin:/usr/local/bin:${PATH}"
ENV HOME="/home/user"
# Install Python dependencies into a shared venv (cached early, before source
# COPY). Only pyproject.toml and uv.lock are needed — the venv lives outside
# the source tree at /home/user/.venv so it survives the later full COPY.
COPY --chown=1000:1000 pyproject.toml uv.lock /home/user/git/vendor/enigmacurry/d.rymcg.tech/
USER user
WORKDIR /home/user/git/vendor/enigmacurry/d.rymcg.tech
RUN uv sync --frozen && \
    ln -s python3 /home/user/.venv/bin/python-d-rymcg-tech
USER root

# Install ytt and script-wizard early (cached before source COPY)
COPY --chown=1000:1000 .tools.lock.json /home/user/git/vendor/enigmacurry/d.rymcg.tech/
RUN set -e; \
    YTT_VERSION=$(jq -r '.dependencies["ytt"].version' .tools.lock.json); \
    SW_VERSION=$(jq -r '.dependencies["script-wizard"].version' .tools.lock.json); \
    case "$(uname -m)" in \
      x86_64)  YTT_ARCH=amd64; SW_ARCH=x86_64 ;; \
      aarch64) YTT_ARCH=arm64; SW_ARCH=aarch64 ;; \
      *)       echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/vmware-tanzu/carvel-ytt/releases/download/v${YTT_VERSION}/ytt-linux-${YTT_ARCH}" -o /usr/local/bin/ytt \
    && chmod +x /usr/local/bin/ytt; \
    curl -fsSL "https://github.com/EnigmaCurry/script-wizard/releases/download/v${SW_VERSION}/script-wizard-Linux-${SW_ARCH}.tar.gz" \
      | tar xz -C /usr/local/bin

COPY --chown=1000:1000 _container/bashrc /home/user/.bashrc
COPY --chown=1000:1000 _container/mg /home/user/.mg

# Install optional extra packages requested at build time
ARG EXTRA_PACKAGES=
RUN if [ -n "${EXTRA_PACKAGES}" ]; then apk add --no-cache ${EXTRA_PACKAGES}; fi

# Copy the d.rymcg.tech repo, optionally switch branch, then strip history
ARG BRANCH=
ARG IMAGE_SOURCE=
ARG IMAGE_REF=localhost/d-rymcg-tech:latest
ARG GIT_REPO=
COPY --chown=1000:1000 . /home/user/git/vendor/enigmacurry/d.rymcg.tech
RUN if [ -n "${BRANCH}" ] && [ -d .git ]; then git checkout "${BRANCH}"; fi && rm -rf .git \
 && ln -s /usr/local/bin/script-wizard _scripts/user/script-wizard \
 && install -m 755 _container/drt /opt/drt \
 && install -m 755 _container/sign-ssh-cert /usr/local/bin/sign-ssh-cert \
 && install -m 755 _container/entrypoint.sh /entrypoint.sh

ARG EDITOR=mg
ENV EDITOR=${EDITOR}
ENV DRT_IMAGE=${IMAGE_REF}
LABEL org.opencontainers.image.source=${IMAGE_SOURCE} \
      drt.branch=${BRANCH} \
      drt.repo=${GIT_REPO}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
