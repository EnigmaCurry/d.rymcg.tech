FROM alpine:latest
ENV TIMEOUT=5
CMD echo 'Sleeping forever ...' && while true; do sleep 1; done
HEALTHCHECK --interval=30s --timeout=30s --start-period=1ms --retries=3 \
    CMD sleep ${TIMEOUT}
