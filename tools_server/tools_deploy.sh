#!/bin/bash
set -euo pipefail

echo "📦 Updating system..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y docker.io
sudo apt-get install -y docker-compose-v2

echo "👤 Creating user tools (if not exists)..."
id tools &>/dev/null || sudo useradd -m -d /home/tools -s /bin/bash tools

echo "🐳 Adding tools to docker group..."
sudo usermod -aG docker tools

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔒 Setting permissions in: $TOOLS_DIR"

find "$TOOLS_DIR" -type d -exec chmod 750 {} \;

find "$TOOLS_DIR" -type f -exec chmod 640 {} \;

chmod 750 "$TOOLS_DIR/$(basename "${BASH_SOURCE[0]}")"

chmod 600 "$TOOLS_DIR/traefik/letsencrypt/acme.json"

echo "📁 Copying contents to /home/tools/..."
sudo cp -r "$TOOLS_DIR"/. /home/tools/

echo "🔑 Setting ownership..."
sudo chown -R tools:tools /home/tools

echo "🌐 Creating Docker networks..."
docker network create monitor-net || true

echo "💾 Creating Docker volumes..."
docker volume create prom_data  || true
docker volume create loki_data  || true
docker volume create alloy_data || true

echo "✅ Done."
