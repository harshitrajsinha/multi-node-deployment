#!/bin/bash

set -euo pipefail

exec &> >(tee -a /tmp/logfile.log)

export DEBIAN_FRONTEND=noninteractive
export HOME=/root

# As root user in root account

# Update and upgrade packages
sudo apt-get update
sudo apt-get upgrade -y

if ! pg_isready --version &>/dev/null; then
    sudo apt install -y postgresql-client
fi

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


if [ ! -d "multi-node-deployment" ]; then
    git clone https://github.com/harshitrajsinha/multi-node-deployment.git
    cd multi-node-deployment

    # Create .env file
    cat <<'EOF' > .env
    
SECRET_KEY=your-secret-key-change-this-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Application Configuration
APP_NAME=Social Media API
APP_VERSION=1.0.0


DB_NAME=social_media_db
DB_USER=postgres
DB_PASSWORD=your_database_password
DB_HOST=localhost
DB_PORT=5432
EOF

fi