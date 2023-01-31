FROM python:3.11 as gather-requirements-txt
ARG UID=1000
ARG GID=1000
ARG USERNAME=python-user
RUN groupadd -g "${GID}" "${USERNAME}" && \
    adduser --uid "${UID}" --gid "${GID}" --gecos "" --disabled-password "${USERNAME}"
USER ${USERNAME}
ENV PATH=/home/${USERNAME}/.local/bin:/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WORKDIR /tmp
RUN pip install poetry
COPY ./pyproject.toml ./poetry.lock* /tmp/
RUN poetry export -f requirements.txt --output requirements.txt --without-hashes



FROM python:3.11 as production
ARG UID=1000
ARG GID=1000
ARG USERNAME=python-user
RUN groupadd -g "${GID}" "${USERNAME}" && \
    adduser --uid "${UID}" --gid "${GID}" --gecos "" --disabled-password "${USERNAME}"
USER ${USERNAME}
ENV PATH=/home/${USERNAME}/.local/bin:/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WORKDIR /code
COPY --from=gather-requirements-txt /tmp/requirements.txt requirements.txt
RUN pip install --no-cache-dir --upgrade -r requirements.txt
COPY ./api api
COPY ./entrypoint.sh /usr/local/bin/entrypoint
VOLUME /code
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/entrypoint"]

