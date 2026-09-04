#!/bin/bash
# ==============================================================================
# Script de pós-provisionamento — aplica secrets e configurações ad-hoc
# Rodar APÓS: kind create cluster + helm installs (make create / terraform apply)
# ==============================================================================
set -e

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/kind-todolist-platform.conf}"
export KUBECONFIG

echo "==> Pós-provisionamento Kind + ArgoCD"

# 1. GHCR Pull Secret (necessário para pods puxarem imagem do GHCR)
echo "==> Criando secret ghcr-pull..."
GH_TOKEN=$(gh auth token 2>/dev/null)
if [ -z "$GH_TOKEN" ]; then
  echo "ERRO: gh auth token não disponível. Faça 'gh auth login' primeiro."
  exit 1
fi
kubectl create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=nikolastsdev \
  --docker-password="$GH_TOKEN" \
  --namespace=todolist 2>/dev/null || kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ghcr-pull
  namespace: todolist
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(echo -n "{\"auths\":{\"ghcr.io\":{\"auth\":\"$(echo -n "nikolastsdev:$GH_TOKEN" | base64 -w0)\"}}}" | base64 -w0)
EOF

# 2. ArgoCD Repo Git Credentials
echo "==> Criando secret argocd-repo-nikolastsdev..."
kubectl create secret generic argocd-repo-nikolastsdev \
  --namespace=argocd \
  --type=Opaque \
  --from-literal=type=git \
  --from-literal=url=https://github.com/nikolastsdev/argo-test-manifests \
  --from-literal=username=nikolastsdev \
  --from-literal=password="$GH_TOKEN" \
  2>/dev/null || kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: argocd-repo-nikolastsdev
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
data:
  type: $(echo -n git | base64 -w0)
  url: $(echo -n https://github.com/nikolastsdev/argo-test-manifests | base64 -w0)
  username: $(echo -n nikolastsdev | base64 -w0)
  password: $(echo -n "$GH_TOKEN" | base64 -w0)
EOF
kubectl label secret argocd-repo-nikolastsdev \
  --namespace=argocd \
  argocd.argoproj.io/secret-type=repository \
  --overwrite 2>/dev/null || true

# 3. Restart ArgoCD repo-server e application-controller para ler o secret
echo "==> Reiniciando ArgoCD controllers..."
kubectl rollout restart deployment argocd-repo-server -n argocd 2>/dev/null || true
kubectl rollout restart statefulset argocd-application-controller -n argocd 2>/dev/null || true

# 4. Criar Application ArgoCD
echo "==> Criando ArgoCD Application todolist-app..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: todolist-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/nikolastsdev/argo-test-manifests
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

# 5. Service NodePort do todolist (porta 5000 -> containerPort 30000 no Kind)
echo "==> Criando service todolist NodePort 30000..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: todolist
  namespace: todolist
spec:
  type: NodePort
  ports:
  - name: http
    port: 5000
    targetPort: 5000
    nodePort: 30000
  selector:
    app: todolist
EOF

echo "==> Aguardando pods..."
sleep 30
echo ""
echo "==> STATUS:"
kubectl get pods -n todolist 2>/dev/null | grep -v Completed
kubectl get pods -n argocd 2>/dev/null | grep -v Completed
echo ""
echo "==> ACESSO:"
echo "   App:       http://localhost:5000"
echo "   ArgoCD:    https://localhost:8080"
echo "   ArgoCD user: admin"
echo "   ArgoCD pass: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d 2>/dev/null)"
