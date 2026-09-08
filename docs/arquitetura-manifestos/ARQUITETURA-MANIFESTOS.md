# Arquitetura de Manifestos YAML — Proposta Clean

## Problema Detectado
- `k8s/helm/todolist-app/templates/` = templates parametrizáveis (Helm) — não usados diretamente no GitOps atual.
- `k8s/infra/` = Kustomize com manifestos concretos, mas sem `app.yaml`, `secrets.yaml`, `configmap.yaml`, `pdb.yaml`, `rbac.yaml`, `ghcr-pull-secret.yaml` (referenciados em `kustomization.yaml` mas ausentes).
- Duplicação conceitual: a mesma aplicação tem uma versão em Helm (parametrizada) e outra em Kustomize (estática), sem sincronização.
- Falta de separação de camadas: namespace, config, database, app, rede e limpeza misturados sem ordem clara.

## Princípios de Arquitetura
1. **DRY (Don't Repeat Yourself)**: uma única fonte de verdade por recurso; Helm para parametrização, Kustomize para concretização (sem duplicar YAMLs de conteúdo).
2. **Camadas Declarativas**: namespace → secrets/config → database → app → ingress/rbac/network → cleanup.
3. **Simplicidade sobre Complexidade**: manifestos simples, sem templates desnecessários quando o escopo é fixo.
4. **GitOps Ready**: estrutura alinhada ao que o ArgoCD sincroniza (`k8s/base/`).
5. **Manutenção Elegante**: arquivos pequenos, com nomes semânticos, sem prefixos numéricos artificiais.

## Estrutura Proposta

```
k8s/
├── base/                 # Manifestos concretos para GitOps (ArgoCD sync)
│   ├── namespace/        # Namespaces (app + db)
│   ├── config/           # ConfigMaps + Secrets (não sensíveis)
│   ├── database/         # PostgreSQL (deployment + service)
│   ├── app/              # Aplicação todolist (deployment, service, hpa, pdb)
│   ├── network/          # Ingress + service account + rbac
│   └── cleanup/          # CronJob de limpeza
├── helm/                 # Chart de referência / parametrizável (opcional)
│   └── todolist-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── overlays/             # Kustomize overlays (dev, prod) — futuro
└── infra/                # Infraestrutura de suporte (namespace base, se necessário)
```

## Decisões
- `base/` será a fonte única de verdade para o GitOps (ArgoCD).
- `helm/` permanece como chart de referência, mas com documentação clara de que não é a fonte de deploy automático.
- `kustomization.yaml` será atualizado para apontar apenas para arquivos existentes e ordenados semanticamente.
- Nenhum recurso será duplicado: o mesmo `ConfigMap` existe apenas em `base/config/`.
- `values.schema.json` no Helm é mantido para validação de parâmetros, mas não replica manifestos.
