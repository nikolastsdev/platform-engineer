SHELL := /bin/bash
TERRAFORM := terraform
TF_DIR := terraform
CLUSTER_NAME ?= todolist-platform
KUBECONFIG := /tmp/kube-kind/kind-$(CLUSTER_NAME).conf

.PHONY: help init plan create destroy reset clean argocd-password

help: ## Lista comandos
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "} {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

init: ## terraform init (portável — sem plugin-dir hardcoded, baixa do registry)
	$(TERRAFORM) -chdir=$(TF_DIR) init

plan: init ## terraform plan
	$(TERRAFORM) -chdir=$(TF_DIR) plan

create: ## Provisiona tudo (init + apply + outputs)
	$(TERRAFORM) -chdir=$(TF_DIR) init
	$(TERRAFORM) -chdir=$(TF_DIR) apply -auto-approve
	@echo ""
	@echo "==> App:        http://localhost:8090 (port-forward) ou localhost:5000 (NodePort)/"
	@echo "==> ArgoCD:     http://localhost:8080/  (user: admin | pass: make argocd-password)"
	@echo "==> Kubeconfig: $(KUBECONFIG)"

destroy: ## Remove tudo (destroy + docker/kind cleanup)
	$(TERRAFORM) -chdir=$(TF_DIR) destroy -auto-approve || true
	@rm -f "$(KUBECONFIG)"
	-@docker rm -f $$(docker ps -a --filter "name=todolist-platform" -q) 2>/dev/null || true
	-@docker network rm kind 2>/dev/null || true
	@echo "==> Limpeza completa."

reset: destroy create ## Limpa tudo e provisiona do zero

clean: ## Remove state local do terraform
	rm -rf $(TF_DIR)/.terraform $(TF_DIR)/.terraform.lock.hcl $(TF_DIR)/terraform.tfstate*
	@echo "==> State removido. Rode 'make create' para subir."

argocd-password: ## Senha do admin ArgoCD (usa kubeconfig do cluster kind)
	@echo "Usando kubeconfig: $(KUBECONFIG)"
	KUBECONFIG=$(KUBECONFIG) kubectl config use-context kind-todolist-platform >/dev/null 2>&1 || true
	KUBECONFIG=$(KUBECONFIG) kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
