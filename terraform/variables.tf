variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "todolist-platform"
}

variable "app_namespace" {
  description = "Kubernetes namespace where the todolist application is deployed"
  type        = string
  default     = "todolist"
}

variable "argocd_repo_url" {
  description = "Git repository URL watched by ArgoCD (GitOps)"
  type        = string
  default     = "https://github.com/nikolastsdev/platform-engineer"
}

variable "argocd_repo_path" {
  description = "Path inside the Git repo where the manifests live"
  type        = string
  default     = "k8s/base"
}

variable "argocd_repo_owner" {
  description = "GitHub owner for ArgoCD repo credentials"
  type        = string
  default     = "nikolastsdev"
}

variable "argocd_repo_name" {
  description = "Repo name for ArgoCD credentials"
  type        = string
  default     = "platform-engineer"
}
