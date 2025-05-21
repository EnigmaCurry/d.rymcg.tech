FROM alpine:latest

RUN apk add --no-cache iperf3

EXPOSE 5201/tcp
EXPOSE 5201/udp

ENTRYPOINT ["iperf3", "-s"]
