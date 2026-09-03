# ADR 0003: Helm como package manager

## Status
**Aprovado**

## Contexto
A aplicação tem 10+ objetos Kubernetes: Deployment, Service, Ingress, HPA, PDB, ConfigMap, Secret, ServiceAccount, Role/RoleBinding, CronJob, e um subchart (PostgreSQL). Manter todos como manifestos soltos é difícil de parametrizar e versionar.

## Decisão
Empacotar a aplicação como Helm chart em `k8s/helm/todolist-app/`. Manter também manifestos puros em `k8s/00..05-*.yaml` como alternativa de baixo nível.

## Consequências

- ✅ Variáveis em `values.yaml` permitem parametrizar replicas, imagens, recursos
- ✅ `helm upgrade --install` é atômico (rollback simples)
- ✅ Reutilizável: chart pode ser deployado em dev/staging/prod com `values-*.yaml`
- ❗ Templates Helm adicionam camada de complexidade
- ❗ Subcharts (postgresql) requerem `helm dependency build` antes de instalar
