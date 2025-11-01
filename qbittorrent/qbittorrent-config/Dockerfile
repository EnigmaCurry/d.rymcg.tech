FROM debian:stable-slim
RUN apt-get -y update && apt-get install -y gettext
ARG DOCKER_CONTEXT
ARG INSTANCE
COPY categories_${DOCKER_CONTEXT}_${INSTANCE}.json /template/categories.json
COPY template/ setup.sh /template/
RUN chmod a+x /template/setup.sh
CMD ["/template/setup.sh"]
