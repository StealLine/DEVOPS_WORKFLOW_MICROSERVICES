#!/bin/bash
set -euo pipefail

echo "📦 Updating system..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y docker.io
sudo apt-get install -y docker-compose-v2

echo "👤 Creating user deploy (if not exists)..."
id deploy &>/dev/null || sudo useradd -m -d /home/deploy -s /bin/bash deploy

echo "🐳 Adding deploy to docker group..."
sudo usermod -aG docker deploy

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy"

echo "🔒 Setting permissions in: $DEPLOY_DIR"

# --- Directories: rwxr-x--- (750) ---
find "$DEPLOY_DIR" -type d -exec chmod 750 {} \;

# --- Regular config files: rw-r----- (640) ---
find "$DEPLOY_DIR" -type f -exec chmod 640 {} \;

# --- acme.json: rw------- (600) ---
chmod 600 "$DEPLOY_DIR/deployVokimi/traefik/letsencrypt/acme.json"

echo "📁cp deploy/ to /home/deploy/..."
sudo cp -r "$DEPLOY_DIR"/. /home/deploy/ 

echo "🔑 Setting ownership..."
sudo chown -R deploy:deploy /home/deploy

docker network create preview_deploy
docker network create production_deploy
docker network create monitor-net
docker volume create alloy_data


echo "✅ Done."
