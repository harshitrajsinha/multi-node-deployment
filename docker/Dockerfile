FROM python:alpine3.24

RUN apk add --no-cache postgresql-client

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    OTEL_SERVICE_NAME=social-media-app \
    OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317 \
    OTEL_EXPORTER_OTLP_PROTOCOL=grpc \
    OTEL_TRACES_EXPORTER=otlp \
    OTEL_EXPORTER_OTLP_INSECURE=true

WORKDIR /app

RUN addgroup -S app && adduser -S -G app app

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

COPY --chown=app:app main.py auth.py database.py models.py ./
COPY --chown=app:app init_db.sh schema.sql seed.sql ./
COPY --chown=app:app routers/ ./routers/

# Add the startup script
COPY --chown=app:app docker/docker-entrypoint.sh /app/docker-entrypoint.sh

RUN chmod +x /app/docker-entrypoint.sh /app/init_db.sh

EXPOSE 8000

USER app

ENTRYPOINT ["/app/docker-entrypoint.sh"]
