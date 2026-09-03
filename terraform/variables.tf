variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "todolist-platform"
}

variable "cluster_version" {
  description = "Kubernetes version for the cluster"
  type        = string
  default     = "v1.30.0"
}

variable "docker_host" {
  description = "Docker daemon endpoint"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "app_namespace" {
  description = "Kubernetes namespace where the todolist application is deployed"
  type        = string
  default     = "todolist"
}

variable "enable_registry" {
  description = "Enable local Docker registry for image pushes"
  type        = bool
  default     = true
}

variable "registry_name" {
  description = "Name of the local Docker registry container"
  type        = string
  default     = "kind-registry"
}

variable "registry_port" {
  description = "Host port exposed by the local registry"
  type        = number
  default     = 5000
}

variable "argocd_repo_url" {
  description = "Git repository URL watched by ArgoCD (GitOps)"
  type        = string
  default     = "https://github.com/nikolastsdev/argo-test-manifests"
}

variable "argocd_repo_path" {
  description = "Path inside the Git repo where the manifests live"
  type        = string
  default     = "k8s/base"
}
