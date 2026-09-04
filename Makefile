# ==============================================================================
# Platform Engineer Challenge — Makefile
#
# `make up` provisiona TUDO via Terraform CLI local, incluindo o cluster kind
# (provider tehcyx/kind) + NGINX Ingress + metrics-server + ArgoCD + Application.
#
# A imagem da app é construída e enviada ao GitHub Packages (GHCR) pelo
# GitHub Actions (hosted runner). O ArgoCD detecta a mudança no repo GitOps
# e sincroniza automaticamente.
# ==============================================================================

SHELL := /bin/bash
TERRAFORM := terraform
TF_DIR := terraform
CLUSTER_NAME ?= todolist-platform
KUBECONFIG := $(HOME)/.kube/kind-$(CLUSTER_NAME).conf

.PHONY: help init plan apply up down destroy create clean verify setup teardown

help: ## Lista os comandos disponíveis
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

init: ## terraform init
	$(TERRAFORM) -chdir=$(TF_DIR) init

plan: init ## terraform plan
	$(TERRAFORM) -chdir=$(TF_DIR) plan

apply: init ## terraform apply -auto-approve (cria cluster kind + ingress + metrics + ArgoCD)
	$(TERRAFORM) -chdir=$(TF_DIR) apply -auto-approve

up: apply ## Provisiona tudo via Terraform (cluster kind + ingress + metrics + ArgoCD)
	@echo ""
	@echo "==> Infraestrutura aplicada."
	@echo "    App:        http://localhost (via ArgoCD/GitOps)"
	@echo "    kubeconfig: $(KUBECONFIG)"
	$(TERRAFORM) -chdir=$(TF_DIR) output

down: destroy ## Alias para destroy (remove tudo, cluster kind incluído)

create: ## Cria cluster via Terraform + port-forwards automáticos
	$(TERRAFORM) -chdir=$(TF_DIR) init
	$(TERRAFORM) -chdir=$(TF_DIR) apply -auto-approve
	@echo "==> App: http://localhost:5000/ (port-forward automático)"
	@echo "==> ArgoCD: http://localhost:8080/ (port-forward automático)"
	@echo "==> Inicie os port-forwards:"
	@echo "    nohup kubectl port-forward -n todolist svc/todolist 5000:80 > /dev/null 2>&1 &"
	@echo "    nohup kubectl port-forward -n argocd svc/argocd-server 8080:443 > /dev/null 2>&1 &"

destroy: ## Remove TUDO via Terraform (cluster kind + ingress + metrics + ArgoCD)
	$(TERRAFORM) -chdir=$(TF_DIR) destroy -auto-approve || true
	@rm -f "$(KUBECONFIG)"
	@echo ""
	@echo "==> Limpando containers/images/docker do cluster (kind)"
	-@docker rm -f $$(docker ps -a --filter "name=todolist-platform" -q) 2>/dev/null || true
	-@docker network rm kind 2>/dev/null || true
	-@docker images --filter "reference=kindest/node*" -q | xargs -r docker rmi -f 2>/dev/null || true
	@echo "==> Limpeza completa."

clean: ## Limpa state/.terraform do Terraform (precisa rodar 'make create' de novo)
	rm -rf $(TF_DIR)/.terraform $(TF_DIR)/.terraform.lock.hcl $(TF_DIR)/terraform.tfstate*
	@echo "==> State do Terraform removido. Rode 'make create' para subir de novo."

verify: ## Verifica a saúde do ambiente
	./scripts/verify.sh

setup: ## Setup completo: make up + credenciais ArgoCD + sync inicial
	./scripts/setup.sh

teardown: ## Remove toda a infraestrutura local (terraform destroy + cleanup)
	./scripts/teardown.sh
