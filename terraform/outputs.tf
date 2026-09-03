output "cluster_name" {
  description = "Nome do cluster kind"
  value       = kind_cluster.this.name
}

output "kubeconfig_path" {
  description = "Caminho do kubeconfig do cluster"
  value       = "~/.kube/kind-${var.cluster_name}.conf"
}

output "registry_url" {
  description = "URL do registry Docker local"
  value       = local.registry_url
}

output "app_namespace" {
  description = "Namespace da aplicação"
  value       = kubernetes_namespace.todolist.metadata[0].name
}

output "argocd_namespace" {
  description = "Namespace do ArgoCD"
  value       = "argocd"
}

output "ingress_http_port" {
  description = "Porta HTTP exposta pela NGINX Ingress"
  value       = 80
}

output "app_url" {
  description = "URL de acesso à aplicação"
  value       = "http://localhost"
}

output "argocd_url" {
  description = "URL de acesso ao ArgoCD (NodePort)"
  value       = "http://localhost:30080"
}
