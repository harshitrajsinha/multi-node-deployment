FROM python:alpine3.24

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
COPY --chown=app:app routers/ ./routers/

EXPOSE 8000

USER app

CMD ["opentelemetry-instrument", "python3", "main.py"]
