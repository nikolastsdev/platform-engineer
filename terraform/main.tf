# ==============================================================================
# Platform Engineer Challenge — Dependencies provisioned by Terraform
# Cluster kind + NGINX Ingress + metrics-server + ArgoCD + Namespaces
# Executado via `make create` (Terraform CLI local)
# A imagem da aplicação vem do GitHub Packages (GHCR) — sem registry local.
#
# IMPORTANTE: não usamos destroy provisioners — quando kind_cluster é
# destruído pelo terraform destroy, todos os recursos dentro morrem junto.
# O Makefile destroy já faz a limpeza extra (kubeconfig, containers).
# ==============================================================================

locals {
  kubeconfig = pathexpand("~/.kube/kind-${var.cluster_name}.conf")
}

# ------------------------------------------------------------------------------
# Cluster kind (provisionado pelo próprio Terraform via provider tehcyx/kind)
# - 1 control-plane com portas 80/443 expostas ao host (acesso via localhost)
# - 3 workers
# ------------------------------------------------------------------------------
resource "kind_cluster" "this" {
  name               = var.cluster_name
  kubeconfig_path    = pathexpand("~/.kube/kind-${var.cluster_name}.conf")

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      extra_port_mappings {
        container_port = 80
        host_port      = 80
        listen_address = "0.0.0.0"
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 443
        listen_address = "0.0.0.0"
        protocol       = "TCP"
      }
    }
    node {
      role = "worker"
    }
    node {
      role = "worker"
    }
    node {
      role = "worker"
    }
  }
}

# ------------------------------------------------------------------------------
# NGINX Ingress Controller (helm, após cluster existir)
# ------------------------------------------------------------------------------
resource "null_resource" "install_ingress" {
  depends_on = [kind_cluster.this]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KUBECONFIG="${local.kubeconfig}"
      echo "==> Instalando NGINX Ingress Controller..."
      helm upgrade --install ingress-nginx ingress-nginx \
        --namespace ingress-nginx --create-namespace \
        --repo https://kubernetes.github.io/ingress-nginx \
        --version 4.11.2 \
        --set controller.replicaCount=1 \
        --set controller.service.type=NodePort \
        --set controller.hostPort.enabled=true \
        --set controller.publishService.enabled=true \
        --wait --timeout 300s
      echo "==> NGINX Ingress OK"
    EOT
  }
}

resource "null_resource" "fix_ingress_to_controlplane" {
  depends_on = [null_resource.install_ingress]
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KUBECONFIG="${local.kubeconfig}"
      echo "==> Force ingress-nginx to run on control-plane with hostNetwork..."
      kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='json' -p='[
        {"op":"replace","path":"/spec/template/spec/hostNetwork","value":true},
        {"op":"replace","path":"/spec/template/spec/dnsPolicy","value":"ClusterFirstWithHostNet"},
        {"op":"add","path":"/spec/template/spec/nodeSelector","value":{"node-role.kubernetes.io/control-plane":""}},
        {"op":"add","path":"/spec/template/spec/tolerations","value":[{"operator":"Exists","key":"node-role.kubernetes.io/control-plane","effect":"NoSchedule"},{"operator":"Exists","key":"node-role.kubernetes.io/master","effect":"NoSchedule"}]}
      ]' || true
      echo "==> Ingress patch OK"
    EOT
  }
}

# ------------------------------------------------------------------------------
# Metrics Server (requerido pelo HPA)
# ------------------------------------------------------------------------------
resource "null_resource" "install_metrics_server" {
  depends_on = [null_resource.fix_ingress_to_controlplane]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KUBECONFIG="${local.kubeconfig}"
      echo "==> Instalando Metrics Server..."
      helm upgrade --install metrics-server metrics-server \
        --namespace kube-system \
        --repo https://kubernetes-sigs.github.io/metrics-server \
        --version 3.12.1 \
        --set args[0]="--kubelet-insecure-tls" \
        --set args[1]="--kubelet-preferred-address-types=InternalIP" \
        --wait --timeout 120s
      echo "==> Metrics Server OK"
    EOT
  }
}

# ------------------------------------------------------------------------------
# ArgoCD (GitOps)
# ------------------------------------------------------------------------------
resource "null_resource" "install_argocd" {
  depends_on = [null_resource.install_ingress]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KUBECONFIG="${local.kubeconfig}"
      echo "==> Instalando ArgoCD..."
      helm upgrade --install argocd argo-cd \
        --namespace argocd --create-namespace \
        --repo https://argoproj.github.io/argo-helm \
        --version 7.4.0 \
        --set configs.params.server.insecure=true \
        --set server.service.type=NodePort \
        --set server.service.nodePorts.https=30080 \
        --wait --timeout 300s
      echo "==> ArgoCD OK"
    EOT
  }
}

# ------------------------------------------------------------------------------
# Namespace da aplicação (via kubectl)
# ------------------------------------------------------------------------------
resource "null_resource" "create_namespaces" {
  depends_on = [null_resource.install_argocd]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KUBECONFIG="${local.kubeconfig}"
      # Define o context do kind como current-context para kubectl funcionar direto
      kubectl config set-current-context kind-todolist-platform --kubeconfig="${local.kubeconfig}" 2>/dev/null || \
        kubectl config use-context kind-todolist-platform --kubeconfig="${local.kubeconfig}" 2>/dev/null || true
      echo "==> Context setado: $(kubectl config current-context --kubeconfig="${local.kubeconfig}" 2>/dev/null || echo 'kind-todolist-platform')"
      echo "==> Criando namespaces..."
      kubectl create namespace todolist --dry-run=client -o yaml | kubectl apply -f -
      kubectl label namespace todolist app=todolist managed=terraform --overwrite
      kubectl create namespace todolist-db --dry-run=client -o yaml | kubectl apply -f -
      # Cria imagePullSecret ghcr-pull para baixar imagem do GHCR
      if [ -n "$${GH_PAT}" ]; then
        PAT="$${GH_PAT}"
      elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        PAT=$(gh auth token)
      else
        PAT=""
      fi
      if [ -n "$PAT" ]; then
        echo "==> Criando imagePullSecret ghcr-pull..."
        kubectl create secret docker-registry ghcr-pull \
          --namespace=todolist --docker-server=ghcr.io \
          --docker-username=nikolastsdev --docker-password="$PAT" \
          --dry-run=client -o yaml | kubectl apply -f -
      fi
      echo "==> Namespaces OK"
    EOT
  }
}

# ------------------------------------------------------------------------------
# Credencial do repo GitOps (ArgoCD)
# Usa o token do `gh auth` (GitHub CLI) para autenticar o repo privado.
# ------------------------------------------------------------------------------
resource "null_resource" "argocd_repo_credentials" {
  depends_on = [null_resource.install_argocd]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export KUBECONFIG="${local.kubeconfig}"
      if ! command -v gh >/dev/null 2>&1; then
        echo "gh CLI não instalado, pulando credencial ArgoCD"
        exit 0
      fi
      if ! gh auth status >/dev/null 2>&1; then
        echo "gh CLI não autenticado, pulando credencial ArgoCD"
        exit 0
      fi
      # Usa token do env GH_PAT (se configurado pelo usuário via gh auth login)
      # Se não houver token, cria com url apenas (funciona para repos públicos)
      if [ -n "$${GH_PAT}" ]; then
        PAT="$${GH_PAT}"
      elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        PAT=$(gh auth token)
      else
        echo "AVISO: Sem token GHCR/GitHub. Criando secret sem password. O ArgoCD pode falhar para repo privado."
        PAT=""
      fi
      kubectl create secret generic argocd-repo-nikolastsdev \
        --namespace=argocd \
        --type=Opaque \
        --from-literal=type=git \
        --from-literal=url=https://github.com/${var.argocd_repo_owner}/${var.argocd_repo_name} \
        --from-literal=username=${var.argocd_repo_owner} \
        --from-literal=password="$PAT" \
        --dry-run=client -o yaml | kubectl apply -f -
      kubectl label secret argocd-repo-nikolastsdev \
        --namespace=argocd \
        argocd.argoproj.io/secret-type=repository \
        --overwrite
      kubectl -n argocd rollout restart deployment/argocd-repo-server >/dev/null 2>&1 || true
      kubectl -n argocd rollout restart statefulset/argocd-application-controller >/dev/null 2>&1 || true
      echo "==> Credencial ArgoCD OK"
    EOT
  }
}
