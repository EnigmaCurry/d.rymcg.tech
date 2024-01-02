FROM python:3.11
ARG UID=1000
ARG GID=1000
ARG USERNAME=python-user
RUN groupadd -g "${GID}" "${USERNAME}" && \
    adduser --uid "${UID}" --gid "${GID}" \
    --gecos "" --disabled-password "${USERNAME}"
USER ${USERNAME}
ENV PATH=/home/${USERNAME}/.local/bin:/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WORKDIR /code
COPY requirements/requirements.txt requirements.txt
RUN pip install --no-cache-dir --upgrade -r requirements.txt
COPY ./app app
VOLUME /code
EXPOSE 8000
CMD gunicorn --worker-tmp-dir /dev/shm --workers=2 --threads=4 --worker-class=gthread --bind 0.0.0.0 api:app
