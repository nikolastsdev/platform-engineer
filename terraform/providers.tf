# ==============================================================================
# Providers do Terraform
#
# O cluster kind é criado ANTES do terraform (via `scripts/ensure-cluster.sh`
# chamado pelo Makefile `make up`), garantindo que o kubeconfig em
# ~/.kube/kind-<cluster>.conf já exista quando o provider kubernetes/helm for
# configurado. O Terraform então apenas provisiona os componentes (registry,
# ingress, metrics-server, ArgoCD + Application GitOps).
# ==============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# ------------------------------------------------------------------------------
# Providers
# ------------------------------------------------------------------------------
provider "docker" {
  host = var.docker_host
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/kind-${var.cluster_name}.conf")
}

provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/kind-${var.cluster_name}.conf")
  }
}
