#!/usr/bin/env bash
# Kubernetes léger (k3s), mono-nœud.
set -euo pipefail

curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

mkdir -p "$HOME/.kube"
cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
grep -q KUBECONFIG "$HOME/.bashrc" || echo 'export KUBECONFIG=$HOME/.kube/config' >> "$HOME/.bashrc"
export KUBECONFIG="$HOME/.kube/config"

echo "Attente du nœud..."
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl get nodes
