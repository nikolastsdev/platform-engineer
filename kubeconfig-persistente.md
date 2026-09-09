# kubeconfig persistente — solução para reiniciar sem perder

## O problema
- `Makefile` usa `KUBECONFIG := /tmp/kube-kind/kind-$(CLUSTER_NAME).conf`
- `terraform/main.tf` usa `pathexpand("/tmp/kube-kind/kind-${var.cluster_name}.conf")`
- /tmp é apagado a cada reboot → kubeconfig + senha Argo somem

## Solução (já aplicada parcial)
1. Mover kubeconfig para `~/.kube/kind-todolist-platform.conf` (persistente)
2. Exportar `KUBECONFIG` no `~/.bashrc` / `~/.zshrc`
3. Salvar senha Argo em `~/.kube/argocd-password.txt` (não na memória)

## Comandos rápidos (depois do cluster subir)
```bash
# Copiar kubeconfig do /tmp (se ainda existir) para persistente
mkdir -p ~/.kube
cp /tmp/kube-kind/kind-todolist-platform.conf ~/.kube/ 2>/dev/null || true

# Exportar para este terminal
export KUBECONFIG="$HOME/.kube/kind-todolist-platform.conf"

# Recuperar senha Argo e salvar
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d > ~/.kube/argocd-password.txt
cat ~/.kube/argocd-password.txt
```
