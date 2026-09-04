# ==============================================================================
# ArgoCD — Application GitOps
# Cria a ArgoCD Application que aponta pro repo Git e sincroniza os manifests.
# ==============================================================================

resource "null_resource" "argocd_app_todolist" {
  depends_on = [null_resource.create_namespaces, null_resource.argocd_repo_credentials]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KUBECONFIG="${local.kubeconfig}"
      kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
EOF
      echo "==> ArgoCD Ingress OK"
      echo "==> Criando ArgoCD Application..."
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
      echo "==> ArgoCD Application OK"
    EOT
  }
}
