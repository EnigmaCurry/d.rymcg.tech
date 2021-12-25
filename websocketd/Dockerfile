## Build container::
FROM debian:11
WORKDIR /usr/local/src/websocketd
RUN apt-get -y update && \
    apt-get install -y build-essential git curl && \
    git clone https://github.com/joewalnes/websocketd.git . && \
    make


## App container (demo count.sh app)::
FROM debian:11
COPY --from=0 /usr/local/src/websocketd /usr/local/bin/
COPY entrypoint.sh /usr/local/bin
ADD https://raw.githubusercontent.com/joewalnes/websocketd/master/examples/bash/count.sh /usr/local/bin/app
RUN chmod a+x /usr/local/bin/app /usr/local/bin/entrypoint.sh

EXPOSE 8080
ENTRYPOINT /usr/local/bin/entrypoint.sh
