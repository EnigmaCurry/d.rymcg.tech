FROM python:3.9-slim

WORKDIR /app
ARG APP

COPY ${APP}/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt
COPY ${APP}/ .

EXPOSE 7860

CMD ["python", "main.py"]
