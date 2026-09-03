# ==============================================================================
# ArgoCD — Applications GitOps
# O ArgoCD (helm_release.argocd em main.tf) recebe esta Application, que
# aponta para o repositório Git e sincroniza os manifests da aplicação.
#
# Usamos `kubectl apply` via null_resource (lendo o kubeconfig exportado pelo
# Terraform) em vez do `kubernetes_manifest` para evitar dependência do provider
# kubernetes, cuja config (host/cert) só fica conhecida após o cluster existir.
# ==============================================================================

resource "null_resource" "argocd_app_todolist" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG="$HOME/.kube/kind-${var.cluster_name}.conf"
      kubectl apply -f - <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: todolist-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${var.argocd_repo_url}
    path: ${var.argocd_repo_path}
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: ${var.app_namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
    EOT
  }
}
