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
find "$TOOLS_DIR/tools" -type d -exec chmod 755 {} \;
find "$TOOLS_DIR/tools" -type f -exec chmod 644 {} \;
chmod 600 "$TOOLS_DIR/tools/traefik/letsencrypt/acme.json"
chmod 755 "$TOOLS_DIR/$(basename "${BASH_SOURCE[0]}")"
 
echo "📁 Copying contents to /home/tools/..."
sudo cp -r "$TOOLS_DIR/tools"/. /home/tools/
 
echo "🔑 Setting ownership..."
sudo chown -R tools:tools /home/tools
sudo chmod 600 /home/tools/traefik/letsencrypt/acme.json
 
echo "🌐 Creating Docker networks..."
sudo docker network create monitor-net || true
sudo docker network create dockhand    || true
sudo docker network create sonarnet    || true

echo "💾 Creating Docker volumes..."
sudo docker volume create prom_data    || true
sudo docker volume create loki_data    || true
sudo docker volume create alloy_data   || true
sudo docker volume create grafana_data || true
sudo docker volume create dockhand_data || true
sudo docker volume create postgresql || true
sudo docker volume create sonarqube_data || true

echo "✅ Done."
