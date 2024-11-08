FROM debian:stable-slim AS gettext
RUN apt-get update && apt-get install -y gettext

FROM gettext
WORKDIR /template
VOLUME /config
COPY setup.sh setup.sql onlyoffice.cnf ./
RUN chmod a+x setup.sh
#RUN ./setup.sh
CMD ["./setup.sh"]
#ENTRYPOINT ["./setup.sh"]
