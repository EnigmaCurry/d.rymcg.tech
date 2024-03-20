ARG MUMBLE_VERSION
FROM mumblevoip/mumble-server:${MUMBLE_VERSION}
USER root
RUN apt-get update && \
    apt install -y python3 python3-pip python-is-python3 build-essential \
    libssl-dev libbz2-dev git wget && \
    pip install zeroc-ice && \
    mkdir /home/mumble && \
    chown -R mumble:mumble /home/mumble

USER mumble
WORKDIR /home/mumble
ENV PATH=/home/mumble/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN wget https://raw.githubusercontent.com/mumble-voip/mumble/1adbe6d9db7bc82234a563c91a5f8772ec0d5811/src/murmur/MumbleServer.ice && slice2py MumbleServer.ice
COPY --chown=mumble test.py .

