ARG VERSION
FROM nginx:${VERSION}
ARG TEMPLATE
COPY ${TEMPLATE} /tmp/default.template
# Create the default nginx config from the template:
# envsubst only replaces the explicit vars specified here as a comma separated list:
ARG HOST
RUN envsubst '$HOST' < /tmp/default.template > \
    /etc/nginx/conf.d/default.conf && \
    rm /tmp/default.template
WORKDIR /app
VOLUME /app
