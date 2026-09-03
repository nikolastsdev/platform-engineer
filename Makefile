# ==============================================================================
# Platform Engineer Challenge — Makefile
#
# Locais que provêm Docker, Docker Network (kind) e o cluster em localhost,
# então o provisioning é feito pelo Terraform CLI rodando na própria máquina
# (make up). O GitHub Actions self-hosted runner lida apenas com a pipeline do
# app (build + deploy via ArgoCD/GitOps).
# ==============================================================================

SHELL := /bin/bash
TERRAFORM := terraform
TF_DIR := terraform
CLUSTER_NAME ?= todolist-platform
KUBECONFIG := $(HOME)/.kube/kind-$(CLUSTER_NAME).conf

.PHONY: help init plan apply up down destroy verify setup teardown setup-runner

help: ## Lista os comandos disponíveis
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

init: ## terraform init
	$(TERRAFORM) -chdir=$(TF_DIR) init

plan: init ## terraform plan
	$(TERRAFORM) -chdir=$(TF_DIR) plan

apply: init ## terraform apply -auto-approve
	$(TERRAFORM) -chdir=$(TF_DIR) apply -auto-approve

up: apply ## Provisiona registry + cluster kind + ingress + metrics + ArgoCD (+ GitOps app)
	@echo ""
	@echo "==> Infraestrutura aplicada."
	@echo "    App:    http://localhost"
	@echo "    ArgoCD: http://localhost:30080"
	@echo "    kubeconfig: $(KUBECONFIG)"
	$(TERRAFORM) -chdir=$(TF_DIR) output

destroy: ## terraform destroy (remove cluster + registry + deps)
	-$(TERRAFORM) -chdir=$(TF_DIR) destroy -auto-approve

down: destroy ## Alias para destroy

verify: ## Verifica a saúde do ambiente
	./scripts/verify.sh

setup: ## Setup completo: make up + build/push imagem + sync ArgoCD GitOps
	./scripts/setup.sh

teardown: ## Remove toda a infraestrutura local
	./scripts/teardown.sh

setup-runner: ## Instala e registra o self-hosted GitHub Actions runner local
	./scripts/setup-runner.sh