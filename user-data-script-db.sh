#!/bin/bash

set -euo pipefail

exec &> >(tee -a /tmp/logfile.log)

export DEBIAN_FRONTEND=noninteractive
export HOME=/root

AWS_REGION="us-east-1"
POSTGRESDB_SECRETS_NAME="postgres/credentials"
DOCKERHUB_SECRETS_NAME="docker/credentials"
GIST_SECRET_NAME="github/gist/credentials"

COMPOSE_GIST_ID="2033bb7c62664b4c600df8d636ae74f3"
INIT_DB_DATA_GIST_ID="126d432fd9640d0c61927d490790315f"
OTEL_DATA_GIST_ID="44bc5cda4d03ff90985f8a5196c22f09"

COMPOSE_FILE_DEST="/opt/compose"
INIT_FILE_DEST="/opt/init"
OTEL_FILE_DEST="/opt/otel"

DB_PASS_FILE_ON_HOST="$HOME/secrets/postgres_password"
DB_USER_FILE_ON_HOST="$HOME/secrets/postgres_user"
DB_NAME_FILE_ON_HOST="$HOME/secrets/postgres_name"

# We will be using POSTGRES image user's group ID to allow it to
# read secret files on host machines in order to mount in the container
# The PID/GID changes based on the image - Debian-based (999), alpine-based (70), DHI. Hence confirm from DockerHub
POSTGRES_IMAGE_GID=70

##########################################################################################

## Update and upgrade packages
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install unzip -y       # required for aws cli
sudo apt-get install jq -y          # required for aws secret manager

##########################################################################################

### Install AWS CLI

if ! aws --version &>/dev/null; then
    curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash
fi
export PATH="/root/.local/bin:/root/.local/share/aws-cli/v2/current/bin:$PATH"

##########################################################################################


### Install Docker
if ! docker --version &>/dev/null; then
    # Add Docker's official GPG key:
    sudo apt update
    sudo apt install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo groupadd -f docker
    sudo usermod -aG docker $USER

fi

### Authenticate Docker

# Retrieve credentials from AWS Secrets Manager
SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "$DOCKERHUB_SECRETS_NAME" \
    --region "$AWS_REGION" \
    --query SecretString \
    --output text)
DOCKER_USERNAME=$(echo "$SECRET" | jq -er '.username')
DOCKER_PASSWORD=$(echo "$SECRET" | jq -er '.password')

# Authenticate with registry (NOT REQUIRED UNLESS DHI IMAGE IS USED)
echo "$DOCKER_PASSWORD" | docker login dhi.io \
    --username "$DOCKER_USERNAME" \
    --password-stdin
# Cleanup
unset SECRET DOCKER_USERNAME DOCKER_PASSWORD
echo "Successfully authenticated with dhi.io"

chmod 700 "$HOME/.docker"
chmod 600 "$HOME/.docker/config.json"

##########################################################################################

### Download files from Gist

mkdir -p "$COMPOSE_FILE_DEST"
mkdir -p "$INIT_FILE_DEST"

# Retrieve PAT from AWS Secrets Manager
GITHUB_TOKEN=$(aws secretsmanager get-secret-value \
    --secret-id "$GIST_SECRET_NAME" \
    --region "$AWS_REGION" \
    --query SecretString \
    --output text | jq -er '.token')

# Download docker compose file
git clone "https://${GITHUB_TOKEN}@gist.github.com/${COMPOSE_GIST_ID}.git" \
    "$COMPOSE_FILE_DEST"

# Download db schema file
git clone "https://${GITHUB_TOKEN}@gist.github.com/${INIT_DB_DATA_GIST_ID}.git" \
    "$INIT_FILE_DEST"

# Download OTEL collector config file
git clone "https://${GITHUB_TOKEN}@gist.github.com/${OTEL_DATA_GIST_ID}.git" \
    "$OTEL_FILE_DEST"

# Clean up token from shell variable
unset GITHUB_TOKEN
echo "Private Gist downloaded successfully"

##########################################################################################

### Get and set Postgres DB credentials

mkdir -p "$HOME/secrets"
chmod 700 "$HOME/secrets"
umask 077

# DB Password
aws secretsmanager get-secret-value \
  --secret-id "$POSTGRESDB_SECRETS_NAME"  \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text | jq -r '.POSTGRES_PASSWORD' \
  > "$DB_PASS_FILE_ON_HOST"

# DB User
aws secretsmanager get-secret-value \
  --secret-id "$POSTGRESDB_SECRETS_NAME"  \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text | jq -r '.POSTGRES_PASSWORD' \
  > "$DB_USER_FILE_ON_HOST"

# DB name
aws secretsmanager get-secret-value \
  --secret-id "$POSTGRESDB_SECRETS_NAME"  \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text | jq -r '.POSTGRES_PASSWORD' \
  > "$DB_NAME_FILE_ON_HOST"

# Assign host owser and PostgreSQL group to files to secure it
sudo chown "$(whoami)":"$POSTGRES_IMAGE_GID" "$DB_PASS_FILE_ON_HOST"
sudo chown "$(whoami)":"$POSTGRES_IMAGE_GID" "$DB_USER_FILE_ON_HOST"
sudo chown "$(whoami)":"$POSTGRES_IMAGE_GID" "$DB_NAME_FILE_ON_HOST"
# Owner gets read/write; PostgreSQL group gets read-only
chmod 640 "$DB_PASS_FILE_ON_HOST"
chmod 640 "$DB_USER_FILE_ON_HOST"
chmod 640 "$DB_NAME_FILE_ON_HOST"

# Not deleting these file as it may be required during re-run.

##########################################################################################

### Start docker container for postgres

cd "$COMPOSE_FILE_DEST"
docker compose up -d

##########################################################################################

### DB Monitoring via Signoz

# Download OTEL collector agent

wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.165.0/otelcol-contrib_0.165.0_linux_amd64.deb
sudo dpkg -i otelcol-contrib_0.165.0_linux_amd64.deb


cd /etc/otelcol-contrib
mv "$OTEL_FILE_DEST"/postgres-monitoring-signoz.yaml ./config.yaml


# Change ENDPOINT value to Signoz server's private IP
cat > /etc/otelcol-contrib/postgres.env <<EOF
POSTGRESQL_USERNAME=$(cat "$DB_USER_FILE_ON_HOST")
POSTGRESQL_PASSWORD=$(cat "$DB_PASS_FILE_ON_HOST")
OTLP_DESTINATION_ENDPOINT="0.0.0.0:4317"
EOF

chown root:root /etc/otelcol-contrib/postgres.env
chmod 600 /etc/otelcol-contrib/postgres.env

# Create systemd override directory
mkdir -p /etc/systemd/system/otelcol-contrib.service.d
# Configure systemd to load environment variables
cat > /etc/systemd/system/otelcol-contrib.service.d/override.conf <<EOF
[Service]
EnvironmentFile=/etc/otelcol-contrib/postgres.env
EOF
# Reload systemd configuration
systemctl daemon-reload

systemctl start otelcol-contrib


echo "DB monitoring setup successfully"

##########################################################################################