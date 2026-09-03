#!/bin/bash
# ==============================================================================
# Setup do Platform Engineer Challenge (local)
#
# Responsabilidades:
#   1. Verifica pré-requisitos (docker, kind, kubectl, terraform, helm)
#   2. Provisiona o cluster via Terraform (make up) — registry + kind + ingress
#      + metrics-server + ArgoCD + Application GitOps
#   3. Constrói e envia a imagem da aplicação para o registry local
#   4. Dispara a sincronização do ArgoCD (GitOps)
# ==============================================================================
set -euo pipefail

# Cores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step()   { echo -e "\n${GREEN}==> $1${NC}"; }
warn()   { echo -e "${YELLOW}WARN: $1${NC}"; }
err()    { echo -e "${RED}ERROR: $1${NC}"; exit 1; }

CLUSTER_NAME="${CLUSTER_NAME:-todolist-platform}"
REGISTRY_NAME="${REGISTRY_NAME:-kind-registry}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
IMAGE="localhost:${REGISTRY_PORT}/todolist:latest"
ARGOCD_NS="${ARGOCD_NS:-argocd}"
KUBECONFIG_PATH="$HOME/.kube/kind-${CLUSTER_NAME}.conf"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ------------------------------------------------------------------------------
# 1. Pré-requisitos
# ------------------------------------------------------------------------------
step "Verificando pré-requisitos"
for cmd in docker kind kubectl terraform helm; do
  command -v "$cmd" >/dev/null 2>&1 || err "'$cmd' não está instalado. Instale e tente novamente."
done
echo "Pré-requisitos OK: docker, kind, kubectl, terraform, helm"

# ------------------------------------------------------------------------------
# 2. Provisionar cluster via Terraform (make up)
# ------------------------------------------------------------------------------
step "Provisionando infraestrutura via Terraform (make up)"
cd "$ROOT"
make up

export KUBECONFIG="$KUBECONFIG_PATH"
if ! kubectl cluster-info >/dev/null 2>&1; then
  err "Cluster não acessível via KUBECONFIG=$KUBECONFIG_PATH"
fi
echo "Cluster acessível: $(kubectl config current-context)"

# ------------------------------------------------------------------------------
# 3. Construir e enviar a imagem da aplicação ao registry local
# ------------------------------------------------------------------------------
step "Construindo e enviando a imagem da aplicação"
if ! docker inspect "$REGISTRY_NAME" >/dev/null 2>&1; then
  err "Registry '$REGISTRY_NAME' não está rodando. Execute 'make up' primeiro."
fi

docker build -t "$IMAGE" -f "$ROOT/todolist-app/Dockerfile" "$ROOT/todolist-app"
docker push "$IMAGE"
echo "Imagem enviada: $IMAGE"

# ------------------------------------------------------------------------------
# 4. Sincronizar aplicação via ArgoCD (GitOps)
# ------------------------------------------------------------------------------
step "Disparando sincronização GitOps (ArgoCD)"
kubectl wait --namespace="$ARGOCD_NS" --for=condition=available deploy/argocd-server --timeout=180s 2>/dev/null || true

APP="todolist-app"
if kubectl -n "$ARGOCD_NS" get application "$APP" >/dev/null 2>&1; then
  kubectl -n "$ARGOCD_NS" patch application "$APP" --type merge \
    -p '{"operation":{"sync":{"revision":"HEAD","prune":true}},"metadata":{"annotations":{"argocd.argoproj.io/refresh":"true"}}}' \
    2>/dev/null || warn "Não foi possível forçar sync via patch; o ArgoCD fará a sincronização automática (auto-sync)"
  echo "Sync do ArgoCD disparado para a Application '$APP'"
else
  warn "Application '$APP' não encontrada. Confirme se o Terraform criou a Application GitOps."
fi

# ------------------------------------------------------------------------------
# 5. Status final
# ------------------------------------------------------------------------------
step "Setup concluído!"
echo ""
echo "Cluster      : $(kubectl config current-context)"
echo "Namespace    : todolist / todolist-db"
echo "App URL      : http://localhost"
echo "ArgoCD URL   : http://localhost:30080"
echo "ArgoCD user  : admin"
echo "ArgoCD senha : kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""