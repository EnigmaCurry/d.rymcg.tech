FROM ejabberd/ecs
USER root
RUN apk add bash
COPY start_ejabberd.sh /home/ejabberd/bin/start_ejabberd.sh
RUN chmod a+x /home/ejabberd/bin/start_ejabberd.sh
USER ejabberd
ENTRYPOINT /home/ejabberd/bin/start_ejabberd.sh
