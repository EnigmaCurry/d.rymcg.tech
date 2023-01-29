FROM alpine

RUN apk add --no-cache shadow \
	&& apk --update add rsync tzdata \
	&& rm -f /etc/rsyncd.conf

COPY wrapper /usr/bin/wrapper

ENTRYPOINT ["/usr/bin/wrapper"]
