# Platform Engineer Challenge

Pipeline CI/CD local com **Terraform + Kind + ArgoCD (GitOps)** para deploy automatizado de uma aplicação Flask com PostgreSQL.

> Atualizado: `make create` / `make destroy` (não `make up`); `app/todolist/` como pasta limpa (não submódulo); CI unificado via `.github/workflows/ci.yaml` (test → build → scan → deploy GitOps mono-repo); imagem `ghcr.io/nikolastsdev/platform-engineer/todolist:latest`; nome do usuário atualizado para **Nikolas Schaffer**.

## Arquitetura (diagrama archify — modo `architecture`)

Diagrama real gerado via `archify` (`docs/arquitetura-manifestos/manifestos-arquitetura.html`):

> **Repo Git → Helm chart (`k8s/helm/todolist-app`) → ArgoCD (selfHeal) → Kind Cluster** • Terraforme só faz bootstrap (cluster + ArgoCD + ghcr-pull, não declara recursos da app).

(Abra `docs/arquitetura-manifestos/manifestos-arquitetura.html` no navegador — é artefato standalone interativo com tema claro/escuro, pan/zoom, busca e exportação PNG/SVG.)

```
┌───────────────────────────────────────────────────────────────────┐
│  Host Machine (Linux)                                            │
│                                                                   │
│  ┌─────────────────┐     ┌──────────────────────────────────┐   │
│  │  make create    │────▶│  Terraform (providers: kind,     │   │
│  │  (CLI)          │     │  null)                           │   │
│  └─────────────────┘     └──────────────────────────────────┘   │
│         │                            │                            │
│         │               ┌────────────┴────────────────┐         │
│         │               │ 1. kind cluster             │         │
│         │               │    ├─ control-plane (4 nodes)         │
│         │               │    ├─ ingress-nginx           │         │
│         │               │    └─ metrics-server         │         │
│         │               │ 2. ArgoCD (Helm + GitOps)   │         │
│         │               │    └─ Application: todolist │         │
│         │               └─────────────────────────────┘         │
│         │                            │                            │
│  ┌──────┴─────────┐          ┌───────┴───────────────┐         │
│  │ GitHub Actions │          │  kind cluster          │         │
│  │ (CI/CD)        │          │  ├─ todolist namespace │         │
│  │ ci.yaml        │          │  ├─ todolist-db (PG)     │         │
│  └────────────────┘          │  └─ app (3 pods)        │         │
│                              └────────────────────────┘         │
└───────────────────────────────────────────────────────────────────┘
```

## Divisão de Responsabilidades

| Etapa | Ferramenta | Onde roda |
|-------|-----------|-----------|
| Provisionamento (cluster + deps) | Terraform + Kind + Helm | CLI local (`make create`) |
| Build da imagem | Docker / build-push-action | GitHub Actions (`.github/workflows/ci.yaml`) |
| Deploy da aplicação | ArgoCD (GitOps sync) | ArgoCD + Helm chart no repo (mono-repo) |

## Comandos

```bash
# Criar / destruir (dois comandos)
make create        # terraform init + apply (provisiona cluster + ArgoCD)
make destroy       # terraform destroy + cleanup

# Acesso via Ingress (provisionado pelo Terraform — não precisa de port-forward)
# ArgoCD (host argocd.localhost) e App (host todolist.localhost / localhost) já são expostos pelo ingress-nginx do Kind.
# Nenhuma gambiarra de kubectl port-forward: a plataforma já entrega os endpoints.

# Se quiser ver internamente (opcional, não obrigatório):
# kubectl get ingress -n argocd -o wide  # visar hosts mapeados
# kubectl get ingress -n todolist -o wide
```

## Estrutura

```
├── terraform/                     # IaC (kind, ingress, metrics, argocd, namespaces)
│   ├── main.tf                    # null_resource + local-exec (kubeconfig via kind)
│   ├── argocd.tf                  # repo credentials (PAT via gh auth token)
│   ├── variables.tf               # argocd_repo_owner, argocd_repo_path (Helm)
│   ├── providers.tf               # kind + null
│   └── outputs.tf                 # app_namespace, kubeconfig_path
├── app/todolist/                  # App Flask (isolado, não submódulo)
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── .github/workflows/
│   └── ci.yaml                    # Test → Build+Push GHCR → Trivy → Deploy GitOps
├── Makefile                       # create / destroy / clean
└── k8s/
    └── helm/
        └── todolist-app/          # ⭐ FONTE ÚNICA — Helm chart (ArgoCD sync)
            ├── Chart.yaml
            ├── values.yaml        # Configurações (imagem, réplicas, env, secrets, db)
            ├── values.schema.json # Validação do schema
            ├── templates/
            │   ├── namespace.yaml      # Namespaces (app + db)
            │   ├── postgresql.yaml     # PostgreSQL (deployment + service + secret)
            │   ├── deployment.yaml     # Aplicação todolist (deployment)
            │   ├── service.yaml        # Service NodePort
            │   ├── ingress.yaml        # Ingress nginx
            │   ├── hpa.yaml            # Autoscaling
            │   ├── pdb.yaml            # Pod Disruption Budget
            │   ├── configmap.yaml      # Configurações da app (env)
            │   ├── secret.yaml         # Credenciais da app
            │   ├── serviceaccount.yaml # Service Account
            │   ├── rbac.yaml           # Role + RoleBinding
            │                         # Nota: ghcr-pull secret é criado pelo Terraform (bootstrap com PAT local, nunca vai pro Git)
            │   └── cronjob.yaml        # Cleanup periódico
            └── tests/                  # helm-unittest (19 testes)
```

### Princípios de Arquitetura (Helm único — GitOps)
- **DRY**: Helm chart é a **única** fonte — nada de duplicação com Kustomize/YAML estático
- **Parametrizável**: `values.yaml` controla tudo (imagem, réplicas, env, secrets, postgres, cron)
- **GitOps Ready**: ArgoCD aponta para `k8s/helm/todolist-app/` no repo (mono-repo) e sincroniza
- **Validado**: `helm lint` 0 falhas, `helm unittest` 19/19, `helm template` gera os 17 recursos
- **Estrutura lógica**: namespace → database → app → network → cleanup (mesma ordem no chart)

## Autenticação ArgoCD → GitHub

- `argocd_repo_credentials` (terraform/null_resource) cria secret `argocd-repo-nikolastsdev` no namespace `argocd`
- Usa `gh auth token` para autenticar repo privado
- `imagePullSecret ghcr-pull` criado no namespace `todolist` para acessar `ghcr.io`

## Pipeline CI (unificado — `ci.yaml`)

- `.github/workflows/ci.yaml`: pipeline único em 4 jobs — `test` (Python + PostgreSQL), `build` (Build+Push GHCR), `scan` (Trivy), `deploy` (GitOps mono-repo, promove imagem no `values.yaml` do Helm chart).
- `context: app/todolist`; `file: app/todolist/Dockerfile`; `permissions: packages: write`; dispara em `push main`.
- Imagem: `ghcr.io/nikolastsdev/platform-engineer/todolist:latest`

## Notes

- `terraform/main.tf` usa `null_resource` + `local-exec` (não usa kubernetes/helm providers — kubeconfig só existe após `kind_cluster` ser criado)
- `kind_config` usa `kubeconfig_path = pathexpand("~/.kube/kind-todolist-platform.conf")`
- O `Dockerfile` usa `python:3.11-slim`; app roda em porta 5000 (gunicorn)

### Badges de Status

| Métrica | Valor | Fonte |
|---------|-------|-------|
| Testes `helm unittest` | **19/19 (100%)** | `.github/workflows/ci.yaml` (`test`) |
| Lint Helm (`helm lint`) | **0 falhas (100%)** | local (`k8s/helm/todolist-app`) |
| CI `test` job | ✅ 100% | GitHub Actions |
| CI `build` job | ✅ 100% | GitHub Actions |
| CI `scan` (Trivy) | ❌ 0% (CVEs `python:3.11-slim`) | GitHub Actions — **não é problema da arquitetura**, é da base Docker |
| CI `deploy` (GitOps) | ⏭️ pulado (depende do scan) | só roda quando Trivy limpo |

> **Nota:** A pipeline de arquitetura está funcional (`test` + `build` confirmados, Helm renderiza 16 recursos sem `default` namespace, CI validado). O deploy só é bloqueado pelo Trivy (imagem base) — resolver a base destrava o deploy GitOps automaticamente, sem mudança no chart.
