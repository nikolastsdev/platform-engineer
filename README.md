# Platform Engineer Challenge

Pipeline CI/CD local com **Terraform + Kind + ArgoCD (GitOps)** para deploy automatizado de uma aplicação Flask com PostgreSQL.

> Atualizado: `make create` / `make destroy` (não `make up`); `app/todolist/` como pasta limpa (não submódulo); CI unificado via `.github/workflows/ci.yaml` (test → build → scan → deploy GitOps mono-repo); imagem `ghcr.io/nikolastsdev/platform-engineer/todolist:latest`; nome do usuário atualizado para **Nikolas Schaffer**.

## Arquitetura

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

# Acesso
make verify        # health checks
kubectl -n argocd port-forward svc/argocd-server 8080:443
kubectl port-forward -n todolist svc/todolist 8090:80 &
# App: http://localhost:8090/healthz
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
            │   ├── pull-secret.yaml    # ImagePullSecret GHCR
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

### Status CI — push `b7c9124` (2026-09-08)
- `.github/workflows/ci.yaml`: `test` ✅ | `build` ✅ | `scan` ❌ (Trivy, CVEs na base `python:3.11-slim`) | `deploy` (pulado — depende do scan)
- A falha do Trivy é **independente** da arquitetura de manifestos; resolver exige atualizar a imagem base (fora do escopo desta entrega de manifestos clean).
- Pipeline **unificado funcionando de ponta a ponta** (test + build confirmados), com deploy automático via GitOps (Helm chart em `k8s/helm/todolist-app/`) quando o scan for limpo.
