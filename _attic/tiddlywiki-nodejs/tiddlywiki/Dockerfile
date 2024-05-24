FROM tiddlywiki-nodejs-base

EXPOSE 8080
VOLUME /tiddlywiki
WORKDIR /tiddlywiki
ENTRYPOINT ["/sbin/tini", "--", "tiddlywiki"]
CMD ["--help"]
