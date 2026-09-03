#!/bin/bash
# ==============================================================================
# Verify — verifica a saúde do ambiente (cluster, ArgoCD, app, healthz)
# ==============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()  { echo -e "${GREEN}[OK]${NC}   $1"; }
fail(){ echo -e "${RED}[FAIL]${NC} $1"; }
info(){ echo -e "${YELLOW}[INFO]${NC} $1"; }

CLUSTER_NAME="${CLUSTER_NAME:-todolist-platform}"
KUBECONFIG_PATH="$HOME/.kube/kind-${CLUSTER_NAME}.conf"
export KUBECONFIG="$KUBECONFIG_PATH"

echo "=== Verificação do ambiente todolist ===="

# Cluster
if kubectl cluster-info >/dev/null 2>&1; then
  ok "Cluster acessível (context: $(kubectl config current-context))"
else
  fail "Cluster não acessível — rode 'make up' primeiro."
  exit 1
fi

# Nodes
echo "--- Nodes ---"
kubectl get nodes -o wide 2>&1 || fail "Falha ao listar nodes"

# Namespaces da app
echo "--- Namespaces ---"
for ns in todolist todolist-db argocd ingress-nginx; do
  if kubectl get ns "$ns" >/dev/null 2>&1; then ok "Namespace $ns"; else fail "Namespace $ns ausente"; fi
done

# Workloads da aplicação
echo "--- Workloads (deploy/po/svc/ing/hpa) ---"
kubectl get deploy,po,svc,ing,hpa -n todolist 2>&1 || fail "Falha ao listar workloads"

# ArgoCD Applications
echo "--- ArgoCD Applications ---"
if kubectl get applications -n argocd 2>/dev/null | grep -q todolist; then
  kubectl get applications -n argocd 2>&1
  SYNC=$(kubectl get application todolist-app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
  HEALTH=$(kubectl get application todolist-app -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
  info "todolist-app sync=$SYNC health=$HEALTH"
else
  fail "ArgoCD Application 'todolist-app' não encontrada"
fi

# Healthz
echo "--- Healthz ---"
if curl -sf --max-time 5 http://localhost/healthz >/dev/null 2>&1; then
  ok "http://localhost/healthz -> 200"
elif curl -sf --max-time 5 http://localhost:8080/healthz >/dev/null 2>&1; then
  ok "http://localhost:8080/healthz -> 200"
else
  info "Aplicação ainda não responde em localhost/localhost:8080 (pode estar iniciando)"
fi

echo ""
echo "App:    http://localhost   (admin / admin123)"
echo "ArgoCD: http://localhost:30080"
echo ""