FROM golang:1.17
## RUN go install github.com/42wim/matterbridge@latest
## Compiling was failing, so just add the binary for now...
ADD https://github.com/42wim/matterbridge/releases/download/v1.23.2/matterbridge-1.23.2-linux-64bit /go/bin/matterbridge

FROM debian:stable-slim
COPY certs/ /etc/ssl/certs/
RUN apt-get update -y && apt-get install -y ca-certificates
COPY --from=0 /go/bin/matterbridge /go/bin/matterbridge
COPY start_matterbridge.sh /go/bin/start_matterbridge.sh
RUN chmod a+rx /go/bin/matterbridge /go/bin/start_matterbridge.sh
ENTRYPOINT /go/bin/start_matterbridge.sh
