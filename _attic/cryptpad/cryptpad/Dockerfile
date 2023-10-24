ARG CRYPTPAD_VERSION
FROM promasu/cryptpad:${CRYPTPAD_VERSION}
ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]
ADD start_cryptpad.sh /bin/start_cryptpad.sh
RUN chmod a+x /bin/start_cryptpad.sh
