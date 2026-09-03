# ==============================================================================
# ArgoCD — Applications GitOps
# O ArgoCD (helm_release.argocd em main.tf) recebe estas Applications, que
# apontam para o repositório Git e sincronizam os manifests da aplicação.
# ==============================================================================

# Application da aplicação todolist (Flask)
resource "kubernetes_manifest" "argocd_app_todolist" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = "todolist-app"
      namespace = "argocd"
    }

    spec = {
      project = "default"
      source = {
        repoURL        = var.argocd_repo_url
        path           = var.argocd_repo_path
        targetRevision = "HEAD"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.app_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [helm_release.argocd]
}
