FROM golang:1.17
ENV SRC=github.com/ortuman/jackal
RUN apt-get update && apt-get install -y git make bash && git clone https://${SRC} /go/src/${SRC}
RUN cd /go/src/${SRC} && make install installctl

FROM debian:stable-slim
VOLUME /config
WORKDIR /jackal
RUN apt-get -y update && apt-get install -y gettext

ADD https://raw.githubusercontent.com/ortuman/jackal/master/scripts/wait-for-it.sh wait-for-it.sh
COPY --from=0 /go/bin/jackal jackal
COPY --from=0 /go/bin/jackalctl jackalctl
COPY start_jackal.sh start_jackal.sh
RUN chmod a+x wait-for-it.sh start_jackal.sh

EXPOSE 5222
ENV PATH $PATH:/jackal
ENV JACKAL_CONFIG_FILE=/config/config
CMD ["./start_jackal.sh"]
