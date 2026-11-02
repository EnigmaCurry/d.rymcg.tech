FROM python:3.12-slim

ARG MCP_UID=10001
ARG MCP_GID=10001

RUN groupadd -g ${MCP_GID} mcp && \
    useradd -u ${MCP_UID} -g ${MCP_GID} -m -s /usr/sbin/nologin mcp

WORKDIR /app

COPY src/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY src/server.py /app/server.py

# Job metadata and rendered sprites live here; mounted as a volume.
RUN mkdir -p /data && chown ${MCP_UID}:${MCP_GID} /data
VOLUME /data

USER mcp
EXPOSE 8000

CMD ["python", "/app/server.py"]
