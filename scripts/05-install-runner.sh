#!/usr/bin/env bash
# Runner GitHub Actions auto-hébergé (architecture x64).
# Usage : REPO_URL=https://github.com/ORG/DEPOT RUNNER_TOKEN=xxxx ./scripts/05-install-runner.sh
# Le jeton : GitHub > dépôt > Settings > Actions > Runners > New self-hosted runner
set -euo pipefail
: "${REPO_URL:?Renseignez REPO_URL}"
: "${RUNNER_TOKEN:?Renseignez RUNNER_TOKEN}"

sudo useradd -m -s /bin/bash runner 2>/dev/null || true
sudo usermod -aG docker runner

VER=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/^v//')
sudo -u runner bash -c "
  set -e
  mkdir -p ~/actions-runner && cd ~/actions-runner
  curl -fsSL -o runner.tgz https://github.com/actions/runner/releases/download/v${VER}/actions-runner-linux-x64-${VER}.tar.gz
  tar xzf runner.tgz
  ./config.sh --unattended --url '${REPO_URL}' --token '${RUNNER_TOKEN}' \
    --name vm-runner --labels self-hosted,linux --replace
"
cd /home/runner/actions-runner
sudo ./svc.sh install runner
sudo ./svc.sh start
echo "Runner installé. Vérifiez qu'il apparaît « Idle » dans GitHub."
