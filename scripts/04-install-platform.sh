#!/usr/bin/env bash
# ArgoCD, Kyverno, supervision. Composants lourds désactivés par défaut.
#   INSTALL_MONITORING=true|false  (Prometheus + Grafana, défaut : true)
#   INSTALL_LOKI=true|false        (défaut : false)
#   INSTALL_FALCO=true|false       (défaut : false)
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
INSTALL_MONITORING="${INSTALL_MONITORING:-true}"
INSTALL_LOKI="${INSTALL_LOKI:-false}"
INSTALL_FALCO="${INSTALL_FALCO:-false}"
cd "$(dirname "$0")/.."

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo add kyverno https://kyverno.github.io/kyverno >/dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo add falcosecurity https://falcosecurity.github.io/charts >/dev/null
helm repo update >/dev/null

# --- ArgoCD (interface sur le port 30090) ---
cat > /tmp/argocd-values.yaml <<'YAML'
configs:
  params:
    server.insecure: true
server:
  service:
    type: NodePort
    nodePortHttp: 30090
YAML
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace -f /tmp/argocd-values.yaml

# --- Kyverno + politiques ---
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --version 3.3.7
echo "Attente de Kyverno..."
kubectl wait --for=condition=Available deploy --all -n kyverno --timeout=300s
kubectl apply -f policies/kyverno-policies.yaml

# --- Supervision ---
if [ "$INSTALL_MONITORING" = "true" ]; then
  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    -n monitoring --create-namespace \
    --set alertmanager.enabled=false \
    --set prometheus.prometheusSpec.retention=3d \
    --set prometheus.service.type=NodePort --set prometheus.service.nodePort=30091 \
    --set grafana.service.type=NodePort --set grafana.service.nodePort=30030
fi

if [ "$INSTALL_LOKI" = "true" ]; then
  helm upgrade --install loki grafana/loki-stack -n monitoring --create-namespace \
    --set grafana.enabled=false --set promtail.enabled=true
fi

if [ "$INSTALL_FALCO" = "true" ]; then
  helm upgrade --install falco falcosecurity/falco -n falco --create-namespace \
    --set driver.kind=modern_ebpf
fi

echo
echo "Mot de passe admin ArgoCD (utilisateur : admin) :"
for i in $(seq 1 30); do
  kubectl -n argocd get secret argocd-initial-admin-secret >/dev/null 2>&1 && break; sleep 5
done
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo "Mot de passe admin Grafana (utilisateur : admin) :"
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || true; echo
