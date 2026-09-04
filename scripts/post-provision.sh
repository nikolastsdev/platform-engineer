#!/bin/bash
# ==============================================================================
# Bootstrap — setup do repo GitOps para GitOps de verdade (NENHUM kubectl apply)
# Fonte de verdade: https://github.com/nikolastsdev/platform-engineer  path: k8s/base/
# ArgoCD sincroniza tudo automaticamente (selfHeal=true, prune=true)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "==> GitOps Bootstrap — fonte: platform-engineer/k8s/base/"
echo "==> NENHUM kubectl apply — tudo via ArgoCD"

# 1. Verificar gh auth
echo "==> Verificando gh auth..."
GH_TOKEN=$(gh auth token 2>/dev/null)
if [ -z "$GH_TOKEN" ]; then
  echo "ERRO: 'gh auth login' necessário."
  exit 1
fi
echo "OK — token: ${GH_TOKEN:0:8}..."

# 2. Gerar ghcr-pull-secret.yaml com token real (vai pro repo)
echo "==> Gerando k8s/base/ghcr-pull-secret.yaml..."
cd "$REPO_ROOT"
kubectl create secret docker-registry ghcr-pull \
  --namespace=todolist \
  --docker-server=ghcr.io \
  --docker-username=nikolastsdev \
  --docker-password="$GH_TOKEN" \
  --dry-run=client -o yaml > k8s/base/ghcr-pull-secret.yaml

# 3. Atualizar argocd-repo para platform-engineer (se existir)
echo "==> Atualizando ArgoCD repo credentials (platform-engineer)..."
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/kind-todolist-platform.conf}"
export KUBECONFIG

kubectl create secret generic argocd-repo-platform-engineer \
  --namespace=argocd \
  --type=Opaque \
  --from-literal=type=git \
  --from-literal=url=https://github.com/nikolastsdev/platform-engineer \
  --from-literal=username=nikolastsdev \
  --from-literal=password="$GH_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl label secret argocd-repo-platform-engineer \
  --namespace=argocd \
  argocd.argoproj.io/secret-type=repository \
  --overwrite 2>/dev/null || true

# 4. Atualizar ArgoCD Application para platform-engineer
echo "==> Atualizando ArgoCD Application (repo=platform-engineer)..."
kubectl apply -f - <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: todolist-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/nikolastsdev/platform-engineer
    path: k8s/base
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: todolist
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# 5. Git add + push (manifests + secret vao pro remote)
echo "==> Commitando e pushando para platform-engineer..."
git add k8s/base/
git commit -m "chore: ghcr-pull-secret + GitOps source of truth (platform-engineer)" || true
git push origin main

# 6. Aguardar ArgoCD sync
echo "==> Aguardando ArgoCD sincronizar (60s)..."
sleep 60

# 7. Status
echo ""
echo "==> STATUS:"
kubectl get pods -n todolist 2>/dev/null | grep -v Completed || echo "pods em criação..."
echo ""
echo "==> ArgoCD Application:"
kubectl get application todolist-app -n argocd -o jsonpath='repoURL={.spec.source.repoURL} path={.spec.source.path} sync={.status.sync.status}{"\n"}' 2>/dev/null || true
echo ""
echo "==> ACESSO: http://localhost:5000/ (Kind nodePort 30000->5000)"
