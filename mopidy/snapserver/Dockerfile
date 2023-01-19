FROM alpine:edge AS builder
WORKDIR /snapcast

RUN apk add npm curl alpine-sdk
RUN npm install --silent --save-dev -g typescript@4.3
RUN curl -L https://github.com/badaix/snapweb/archive/refs/tags/v0.2.0.tar.gz | tar xz --directory / && cd /snapweb-0.2.0 && make



FROM alpine:edge

RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories
RUN apk add --no-cache gdb librespot snapcast-server dbus avahi avahi-compat-libdns_sd

COPY --from=builder /snapweb-0.2.0/dist /usr/share/snapserver/snapweb
COPY startup.sh startup.sh
RUN ln -s /etc/snapserver/snapserver.conf /etc/snapserver.conf && \
    chmod +x ./startup.sh

EXPOSE 1704 1705 1780
ENTRYPOINT [ "./startup.sh" ]
