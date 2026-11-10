# Retrieve AWS Secrets Manager Secrets and Mount Them into Docker

This approach retrieves database credentials from AWS Secrets Manager on the EC2 host, writes them to a protected file, and mounts that file into the Docker container as read-only.

## 1. Fetch the secret on EC2

Assume the Secrets Manager secret contains JSON similar to:

```json
{
  "DB_NAME": "social_media_db",
  "DB_USER": "postgres",
  "DB_PASSWORD": "my-secret-password",
  "DB_HOST": "my-rds-endpoint",
  "DB_PORT": "5432"
}
```

In your EC2 User Data script:

```bash
#!/bin/bash
set -euo pipefail

mkdir -p /run/social-media-secrets
chmod 700 /run/social-media-secrets

aws secretsmanager get-secret-value \
    --secret-id social-media-db \
    --query SecretString \
    --output text > /run/social-media-secrets/db.json

chmod 600 /run/social-media-secrets/db.json
```

The EC2 instance needs:
- AWS CLI installed.
- An attached IAM instance profile with narrowly scoped `secretsmanager:GetSecretValue` permission for this secret.
- Network access to AWS Secrets Manager.

## 2. Mount the secret into the container

Run the container with the secret file mounted read-only:

```bash
docker run -d \
    --name social-media \
    -p 8000:8000 \
    -v /run/social-media-secrets/db.json:/run/secrets/db.json:ro \
    social-media:latest
```

The secret is not added to the container's environment configuration.

## 3. Read the secret in the entrypoint

Install `jq` in your Docker image, then update `docker-entrypoint.sh`:

```sh
#!/bin/sh
set -eu

SECRET_FILE="/run/secrets/db.json"

export DB_NAME="$(jq -r '.DB_NAME' "$SECRET_FILE")"
export DB_USER="$(jq -r '.DB_USER' "$SECRET_FILE")"
export DB_PASSWORD="$(jq -r '.DB_PASSWORD' "$SECRET_FILE")"
export DB_HOST="$(jq -r '.DB_HOST' "$SECRET_FILE")"
export DB_PORT="$(jq -r '.DB_PORT' "$SECRET_FILE")"

echo "Running database initialization..."
./init_db.sh

exec uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Your existing `init_db.sh` can remain unchanged because the entrypoint exports the variables before invoking it.

## 4. Important security and operational notes

- Docker does not natively fetch secrets from AWS Secrets Manager with this `docker run` command. The EC2 host fetches the secret first and mounts the file into the container.
- The `:ro` mount prevents the container from modifying the mounted secret file.
- Protect the host file and its parent directory with restrictive permissions. Ensure the container's `app` user can read the mounted file; adjust ownership or group permissions carefully if needed.
- Do not bake secrets into the Docker image or commit them to source control.
- This fetches the secret when the EC2 bootstrap script runs. If the secret rotates later, the mounted file will not automatically be refreshed. Retrieve the new value and restart or reload the application as appropriate.
- Environment variables exported by the entrypoint are available to the child processes, but may still be visible through process or runtime inspection. Reading directly from the mounted file in the application can reduce that exposure further.

## 5. Approach comparison

| Consideration | Pass with `-e` | Mount a secret file |
|---|---|---|
| Visible in `docker inspect` environment | Yes | No |
| AWS CLI required inside container | No | No |
| AWS CLI required on EC2 | Yes | Yes |
| Secret delivered as a file | No | Yes |
| Read-only mount | No | Yes |

**Recommendation:** For this EC2 deployment, retrieve the secret on the host and mount it read-only. Use an IAM instance profile with least-privilege access to Secrets Manager.
