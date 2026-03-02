FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates gnupg && \
    mkdir -p /etc/apt/keyrings && \
    wget -q -O /etc/apt/keyrings/mopidy-archive-keyring.gpg https://apt.mopidy.com/mopidy.gpg && \
    wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/bookworm.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      procps \
      tzdata \
      sudo \
      build-essential \
      python3-dev \
      python3-pip \
      python3-gst-1.0 \
      python3-wheel \
      gir1.2-gstreamer-1.0 \
      gir1.2-gst-plugins-base-1.0 \
      gstreamer1.0-plugins-good \
      gstreamer1.0-plugins-ugly \
      gstreamer1.0-plugins-bad \
      gstreamer1.0-libav \
      gstreamer1.0-tools \
      libxml2-dev \
      libxslt1-dev \
      libffi-dev \
      libz-dev \
      python3-setuptools \
      git && \
    rm -rf /var/lib/apt/lists/* && \
    pip3 install --break-system-packages \
      Mopidy \
      Mopidy-MPD \
      Mopidy-Local \
      Mopidy-SomaFM \
      Mopidy-TuneIn \
      Mopidy-Iris && \
    python3 -m pip install --break-system-packages \
      "git+https://github.com/mopidy/mopidy-soundcloud@fc766b0bf17feb4fc989029b92a315a10ff453ee"

RUN PYTHON_SITE=$(python3 -c "import site; print(site.getsitepackages()[0])") && \
    touch /IS_CONTAINER && \
    useradd -ms /bin/bash mopidy && \
    sh -c "echo \"mopidy ALL=NOPASSWD: ${PYTHON_SITE}/mopidy_iris/system.sh, /usr/bin/apt*\" >> /etc/sudoers" && \
    sed -i "s+--config .*mopidy.conf+--config /home/mopidy/.config/mopidy/mopidy.conf+g" \
      "${PYTHON_SITE}/mopidy_iris/system.sh" && \
    mkdir -p /media/music && \
    chown mopidy:mopidy /media/music
VOLUME /media/music

COPY mopidy_default.conf /mopidy_default.conf
COPY mopidy.sh /usr/local/bin/mopidy.sh
USER mopidy
RUN mkdir -p /home/mopidy/.config/mopidy/ && cp /mopidy_default.conf /home/mopidy/.config/mopidy/mopidy.conf

EXPOSE 6600 6680
ENTRYPOINT ["/usr/local/bin/mopidy.sh"]
