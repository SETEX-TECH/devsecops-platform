#!/usr/bin/env bash
# Outils de base : Docker, Trivy, Helm, Python, agent QEMU (Proxmox).
set -euo pipefail

sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get install -y ca-certificates curl git jq unzip gnupg \
  python3-venv python3-pip qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent || echo "Agent QEMU non actif (non bloquant)"

# Docker
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
fi
sudo usermod -aG docker "$USER"

# Trivy (scan des dépendances et des images)
if ! command -v trivy >/dev/null; then
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sudo sh -s -- -b /usr/local/bin
fi

# Helm
if ! command -v helm >/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash  # nosemgrep
fi

echo
echo "Terminé. DÉCONNECTEZ-VOUS puis reconnectez-vous (ou tapez : newgrp docker)"
echo "pour que le groupe docker soit pris en compte."
