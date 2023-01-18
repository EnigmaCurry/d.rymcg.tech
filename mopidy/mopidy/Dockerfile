FROM debian:buster-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    gnupg && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/share/keyrings
RUN wget -q -O /usr/local/share/keyrings/mopidy-archive-keyring.gpg https://apt.mopidy.com/mopidy.gpg
RUN wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/buster.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
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
    # libspotify12 \
    # libspotify-dev \
    # python3-spotify \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install \
    Mopidy \
    Mopidy-MPD \
    Mopidy-Local \
    # Mopidy-YTMusic \
    # Mopidy-Spotify \
    Mopidy-TuneIn \
    Mopidy-Iris

RUN touch /IS_CONTAINER
RUN useradd -ms /bin/bash mopidy
RUN sh -c 'echo "mopidy ALL=NOPASSWD: /usr/local/lib/python3.7/dist-packages/mopidy_iris/system.sh, /usr/bin/apt*" >> /etc/sudoers'
RUN sed -i 's+--config .*mopidy.conf+--config /home/mopidy/.config/mopidy/mopidy.conf+g' /usr/local/lib/python3.7/dist-packages/mopidy_iris/system.sh  # Fixes the silly iris script with built-in paths

COPY mopidy_default.conf /mopidy_default.conf
COPY mopidy.sh /usr/local/bin/mopidy.sh
USER mopidy
RUN mkdir -p /home/mopidy/.config/mopidy/ && cp /mopidy_default.conf /home/mopidy/.config/mopidy/mopidy.conf

EXPOSE 6600 6680
ENTRYPOINT ["/usr/local/bin/mopidy.sh"]
