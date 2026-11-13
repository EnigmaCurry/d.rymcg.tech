## Build container (websocketd's Makefile now expects Go to be installed)::
FROM golang:1.24-trixie
WORKDIR /usr/local/src/websocketd
RUN git clone https://github.com/joewalnes/websocketd.git . && \
    CGO_ENABLED=0 go build -o websocketd .


## App container (demo count.sh app)::
FROM debian:13
COPY --from=0 /usr/local/src/websocketd /usr/local/bin/
COPY entrypoint.sh /usr/local/bin
ADD https://raw.githubusercontent.com/joewalnes/websocketd/master/examples/bash/count.sh /usr/local/bin/app
RUN chmod a+x /usr/local/bin/app /usr/local/bin/entrypoint.sh

EXPOSE 8080
ENTRYPOINT /usr/local/bin/entrypoint.sh
