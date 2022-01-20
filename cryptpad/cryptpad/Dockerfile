FROM promasu/cryptpad:nginx
ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]
ADD start_cryptpad.sh /bin/start_cryptpad.sh
RUN chmod a+x /bin/start_cryptpad.sh
