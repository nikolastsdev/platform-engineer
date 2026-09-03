#!/bin/bash
# ==============================================================================
# Teardown — remove a infraestrutura local provisionada pelo `make up`
#   - remove a Application GitOps (ArgoCD) e o ArgoCD
#   - roda terraform destroy (cluster kind + registry + deps)
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step() { echo -e "\n${GREEN}==> $1${NC}"; }

CLUSTER_NAME="${CLUSTER_NAME:-todolist-platform}"
KUBECONFIG_PATH="$HOME/.kube/kind-${CLUSTER_NAME}.conf"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Parar ArgoCD antes de destruir o cluster (evita garbage)
export KUBECONFIG="$KUBECONFIG_PATH"
if kubectl cluster-info >/dev/null 2>&1; then
  step "Limpando resources gerenciados (declarative app)" 2>/dev/null || true
fi

step "Executando terraform destroy (via make down)"
cd "$ROOT"
make down || {
  echo ""
  warn() { echo -e "${YELLOW}WARN: $1${NC}"; }
  warn "terraform destroy falhou — pode já estar destruído ou o estado não existe."
}

# Fallback: remover cluster e registry via kind/docker caso o terraform não os gerencie
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  step "Removendo cluster kind remanescente"
  kind delete cluster --name "$CLUSTER_NAME"
fi

# Remove o container do registry (se o docker provider não o removeu)
if docker inspect kind-registry >/dev/null 2>&1; then
  step "Removendo registry local"
  docker rm -f kind-registry 2>/dev/null || true
fi

echo ""
echo "Teardown concluído."