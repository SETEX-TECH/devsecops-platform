#!/usr/bin/env bash
# Registre d'images local (localhost:5000) et configuration de k3s pour l'utiliser.
set -euo pipefail

docker volume create registry-data >/dev/null
docker rm -f registry >/dev/null 2>&1 || true
docker run -d --restart=always --name registry \
  -p 127.0.0.1:5000:5000 -v registry-data:/var/lib/registry registry:2

sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/registries.yaml >/dev/null <<'YAML'
mirrors:
  "localhost:5000":
    endpoint:
      - "http://localhost:5000"
YAML
sudo systemctl restart k3s
echo "Registre prêt sur localhost:5000"
