#!/bin/sh
set -euo pipefail

echo "Starting Social Media App container..."

# Initialize the database before starting FastAPI
echo "Running database initialization..."
./init_db.sh

echo "Database initialization successful."
echo "Starting FastAPI with OpenTelemetry instrumentation..."

# Replace the shell with the original application process
exec opentelemetry-instrument python3 main.py
