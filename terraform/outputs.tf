output "cluster_name" {
  description = "Nome do cluster kind"
  value       = var.cluster_name
}

output "kubeconfig_path" {
  description = "Caminho do kubeconfig do cluster"
  value       = "~/.kube/kind-${var.cluster_name}.conf"
}

output "app_namespace" {
  description = "Namespace da aplicação"
  value       = var.app_namespace
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
  description = "Acesso ao ArgoCD (kind não expõe NodePort no host — use port-forward)"
  value       = "kubectl -n argocd port-forward svc/argocd-server 8080:443  ->  https://localhost:8080"
}
