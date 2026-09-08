# Arquitetura de Manifestos — Entrega Aplicada

## Estado Anterior (problemas)
- `k8s/helm/`: templates parametrizáveis, mas sem sincronização com deploy real.
- `k8s/infra/`: Kustomize com `kustomization.yaml` apontando para arquivos inexistentes (app.yaml, secrets.yaml, etc.).
- `k8s/infra/namespace-*.yaml`: namespaces duplicados com base, sem separação de camadas.
- Duplicação real entre `k8s/helm/` e `k8s/base/` (o mesmo `deployment.yaml` em dois lugares).

## Estado Final (entregue) — Helm chart único, GitOps puro
- `k8s/helm/todolist-app/` é a **fonte única** de todos os recursos declarativos:
  1. `namespace.yaml` — namespaces (`todolist`, `todolist-db`)
  2. `postgresql.yaml` — PostgreSQL (deployment + service + secret)
  3. `deployment.yaml` — aplicação `todolist` (probes, securityContext, imagePullSecret)
  4. `service.yaml` — Service NodePort
  5. `ingress.yaml` — Ingress nginx
  6. `hpa.yaml` — HPA (2–10 réplicas, CPU 70% / mem 80%)
  7. `pdb.yaml` — PDB (minAvailable 1)
  8. `configmap.yaml` — ConfigMap da app (env)
  9. `secret.yaml` — credenciais da app
  10. `serviceaccount.yaml` — Service Account
  11. `rbac.yaml` — Role + RoleBinding
  12. `pull-secret.yaml` — ImagePullSecret GHCR (`ghcr-pull`)
  13. `cronjob.yaml` — CronJob de limpeza
  14. `tests/` — 19 testes `helm-unittest` + snapshot
- `k8s/base/` **removido** — era a fonte da duplicação com o Helm.
- `k8s/infra/` **removido** — apontava para arquivos que não existiam.
- Terraform: aponta o ArgoCD para `k8s/helm/todolist-app` (`argocd_repo_path`) — auto-detect via `Chart.yaml`; provisiona cluster + ArgoCD + credenciais (não mais recursos da app).
- CI: `k8s/base/app/deployment.yaml` → promoção de imagem editando `image.tag` no `values.yaml` do chart; ArgoCD (selfHeal) re-sincroniza.
- `docs/arquitetura-manifestos/ARQUITETURA-MANIFESTOS.md`: princípios (DRY, simplicidade, GitOps puro).
- `docs/arquitetura-manifestos/manifestos-arquitetura.html`: diagrama de arquitetura (archify).

## Princípios Aplicados
- **DRY**: um recurso, um template. Nenhum YAML duplicado — Helm é a única fonte.
- **Simplicidade**: `values.yaml` controla tudo; sem Kustomize, sem camadas redundantes.
- **Elegância**: templates organizados por função; nomes semânticos; schema JSON valida o `values`.
- **GitOps puro**: repo Git é a fonte da verdade — Terraform só provisiona o cluster; ArgoCD sincroniza do repo.

## Validação
- `helm lint` → 0 falhas
- `helm template --namespace todolist` → 17 recursos (app + db), nenhum em `default`
- `helm unittest` → 19/19 pass
- `helm push`/package prontos para CI (`ci.yaml`: test → build → scan → deploy)