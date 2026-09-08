# Arquitetura de Manifestos — Entrega Aplicada

## Estado Anterior (problemas)
- `k8s/helm/`: templates parametrizáveis, mas sem sincronização com deploy real.
- `k8s/infra/`: Kustomize com `kustomization.yaml` apontando para arquivos inexistentes (app.yaml, secrets.yaml, etc.).
- `k8s/infra/namespace-*.yaml`: namespaces duplicados com base, sem separação de camadas.
- Nenhum `k8s/base/`: o README mencionava `base/` como GitOps, mas o diretório não existia fisicamente.

## Estado Atual (entregue)
- `k8s/base/` criado com 11 manifestos organizados em 6 camadas:
  1. `namespace/` — namespaces (`todolist`, `todolist-db`)
  2. `config/` — ConfigMap + Secret
  3. `database/` — PostgreSQL (deployment + service, movido de `infra/`)
  4. `app/` — Deployment da aplicação (`todolist`)
  5. `network/` — Service, ServiceAccount, Ingress, RBAC
  6. `cleanup/` — CronJob de limpeza
- `k8s/infra/kustomization.yaml` atualizado: aponta apenas para arquivos existentes em `base/`, ordem semântica declarativa, sem prefixos numéricos.
- `k8s/helm/` mantido intacto: referência parametrizável, sem duplicação com `base/`.
- `docs/arquitetura-manifestos/ARQUITETURA-MANIFESTOS.md`: princípios (DRY, camadas, simplicidade, GitOps ready).
- `docs/arquitetura-manifestos/manifestos-arquitetura.html`: diagrama de arquitetura (archify, validado e entregue).

## Princípios Aplicados
- **DRY**: um recurso, um arquivo. Nenhum YAML duplicado entre `base/` e `helm/`.
- **Simplicidade**: manifestos pequenos, sem templates desnecessários no fluxo GitOps.
- **Elegância**: nomes semânticos (`namespace/`, `config/`, `database/`), ordem declarativa, sem numeração artificial.
- **Funcionalidade**: todos os YAMLs validados (`python3 -c yaml.safe_load`), Kustomize atualizado, Helm preservado.
