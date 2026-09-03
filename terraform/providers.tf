# ==============================================================================
# Providers — provisionamento local via Terraform (executado pelo `make up`)
# ==============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.5"
    }
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
# Kind Cluster (gerenciado pelo Terraform)
# ------------------------------------------------------------------------------
resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    api_version = "kind.x-k8s.io/v1alpha4"
    kind        = "Cluster"

    node {
      role = "control-plane"
      extra_port_mappings {
        container_port = 80
        host_port      = 80
        listen_address = "0.0.0.0"
        protocol       = "tcp"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 443
        listen_address = "0.0.0.0"
        protocol       = "tcp"
      }
    }

    node { role = "worker" }
    node { role = "worker" }
    node { role = "worker" }
  }
}

# Exporta o kubeconfig num arquivo dedicado (não mexe no ~/.kube/config global)
resource "null_resource" "kubeconfig" {
  provisioner "local-exec" {
    command = "mkdir -p ~/.kube && echo '${kind_cluster.this.kubeconfig}' > ~/.kube/kind-${var.cluster_name}.conf && chmod 600 ~/.kube/kind-${var.cluster_name}.conf"
  }
  depends_on = [kind_cluster.this]
}

# Configuração dos providers apontando para o cluster kind recém-criado.
# O `kind_cluster` é o "source of truth" das credenciais.
provider "docker" {
  host = var.docker_host
}

provider "kubernetes" {
  host                   = kind_cluster.this.endpoint
  cluster_ca_certificate = base64decode(kind_cluster.this.cluster_ca_certificate)
  client_certificate     = base64decode(kind_cluster.this.client_certificate)
  client_key             = base64decode(kind_cluster.this.client_key)
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.this.endpoint
    cluster_ca_certificate = base64decode(kind_cluster.this.cluster_ca_certificate)
    client_certificate     = base64decode(kind_cluster.this.client_certificate)
    client_key             = base64decode(kind_cluster.this.client_key)
  }
}
