#!/bin/bash
# Recupera senha do admin ArgoCD do kubeconfig persistente
# Executar depois de fazer login novamente (após reinício do computador):
#   source scripts/recuperar-argocd.sh

export KUBECONFIG="${HOME}/.kube/kind-todolist-platform.conf"
echo "==> Usando kubeconfig persistente: $KUBECONFIG"

if [ -f "$KUBECONFIG" ]; then
    echo "Arquivo kubeconfig encontrado. OK."
else
    echo "AVISO: $KUBECONFIG NÃO ENCONTRADO."
    echo "Se o cluster ainda não foi criado após reiniciar, rode: make create"
    echo "Se já existia, copie de algum backup ou recrie."
fi

# Recupera senha do admin Argo e salva em arquivo persistente
PASSWORD_FILE="${HOME}/.kube/argocd-password.txt"

if [ -f "$KUBECONFIG" ]; then
    if kubectl -n argocd get secret argocd-initial-admin-secret >/dev/null 2>&1; then
        kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d > "$PASSWORD_FILE"
        echo "==> Senha Argo recuperada e salva em: $PASSWORD_FILE"
        echo "==> Senha: $(cat "$PASSWORD_FILE")"
    else
        echo "==> Secret argocd-initial-admin-secret não encontrado (ArgoCD pode não estar instalado)."
        echo "    Rode 'make create' se for necessário."
    fi
fi
