# ==============================================================================
# Platform Engineer Challenge — Dependencies provisioned by Terraform
# Registry + namespaces + NGINX Ingress + metrics-server + ArgoCD
# Executado via `make up` (Terraform CLI local)
# ==============================================================================

locals {
  registry_url = "${var.registry_name}:${var.registry_port}"
}

# ------------------------------------------------------------------------------
# Registry Docker local (para o cluster puxar as imagens construídas localmente)
# ------------------------------------------------------------------------------
resource "docker_container" "registry" {
  count   = var.enable_registry ? 1 : 0
  name    = var.registry_name
  image   = "registry:2"
  restart = "always"

  ports {
    internal = 5000
    external = var.registry_port
  }

  provisioner "local-exec" {
    command = "docker network connect kind ${var.registry_name} 2>/dev/null || true"
  }
}

# Configura o cluster para considerar o registry local como inseguro/insecure
resource "null_resource" "registry_config" {
  count      = var.enable_registry ? 1 : 0
  depends_on = [docker_container.registry, kind_cluster.this, null_resource.kubeconfig]

  provisioner "local-exec" {
    command = <<-EOT
      KUBECONFIG=~/.kube/kind-${var.cluster_name}.conf kubectl create namespace kube-public --dry-run=client -o yaml | KUBECONFIG=~/.kube/kind-${var.cluster_name}.conf kubectl apply -f -
      KUBECONFIG=~/.kube/kind-${var.cluster_name}.conf kubectl -n kube-public create configmap local-registry-hosting \
        --from-literal=host=${local.registry_url} \
        --from-literal=help-address="http://0.0.0.0:${var.registry_port}" \
        -o yaml --dry-run=client | KUBECONFIG=~/.kube/kind-${var.cluster_name}.conf kubectl apply -f -
    EOT
  }
}

# ------------------------------------------------------------------------------
# Namespace da aplicação
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "todolist" {
  metadata {
    name = var.app_namespace
    labels = {
      app     = "todolist"
      managed = "terraform"
    }
  }
}

# ------------------------------------------------------------------------------
# NGINX Ingress Controller
# ------------------------------------------------------------------------------
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.2"
  create_namespace = true

  set {
    name  = "controller.replicaCount"
    value = "2"
  }
  set {
    name  = "controller.service.type"
    value = "NodePort"
  }
  set {
    name  = "controller.service.nodePorts.http"
    value = "30080"
  }
  set {
    name  = "controller.publishService.enabled"
    value = "true"
  }

  depends_on = [kind_cluster.this, null_resource.kubeconfig, null_resource.registry_config]
}

# ------------------------------------------------------------------------------
# Metrics Server (requerido pelo HPA)
# ------------------------------------------------------------------------------
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  version    = "3.12.1"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
  set {
    name  = "args[1]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }

  depends_on = [helm_release.nginx_ingress]
}

# ------------------------------------------------------------------------------
# ArgoCD (GitOps)
# ------------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.4.0"
  create_namespace = true

  set {
    name  = "configs.params.server.insecure"
    value = "true"
  }
  set {
    name  = "server.service.type"
    value = "NodePort"
  }

  depends_on = [helm_release.nginx_ingress]
}
