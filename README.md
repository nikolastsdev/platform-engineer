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
| Deploy da aplicação | ArgoCD (GitOps sync) | ArgoCD + repo `nikolastsdev/argo-test-manifests` |

## Comandos

```bash
# Criar / destruir (dois comandos)
make create        # terraform init + apply
make destroy       # terraform destroy + cleanup

# Acesso
make verify        # health checks
kubectl -n argocd port-forward svc/argocd-server 8080:443
kubectl port-forward -n todolist svc/todolist 8090:80 &
# App: http://localhost:8090/healthz
```

## Estrutura Atualizada

```
├── terraform/                     # IaC (kind, ingress, metrics, argocd, namespaces)
│   ├── main.tf                    # null_resource + local-exec (kubeconfig via kind)
│   ├── argocd.tf                  # repo credentials (PAT via gh auth token)
│   ├── variables.tf               # argocd_repo_owner, argocd_repo_name
│   ├── providers.tf               # kind + null
│   └── outputs.tf                 # app_namespace, kubeconfig_path
├── app/todolist/                  # App Flask (isolado, não submódulo)
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── .github/workflows/
│   └── ci.yaml                    # Test → Build+Push GHCR → Trivy → Deploy GitOps
├── Makefile                       # create / destroy / clean
├── k8s/
│   ├── base/                      # Fonte única — manifests GitOps (ArgoCD sync)
│   │   ├── namespace/             #   Namespaces (app + db)
│   │   ├── config/                #   ConfigMap + Secret
│   │   ├── database/              #   PostgreSQL (deployment + service)
│   │   ├── app/                   #   Aplicação todolist (deployment)
│   │   ├── network/               #   Service, ServiceAccount, Ingress, RBAC
│   │   └── cleanup/               #   CronJob de limpeza
│   ├── helm/                      # Chart parametrizável (referência, não deploy automático)
│   │   └── todolist-app/
│   └── infra/
│       └── kustomization.yaml     # Aponta para k8s/base/ — ordem semântica declarativa
├── docs/
│   └── arquitetura-manifestos/    # Proposta clean + diagrama archify
│       ├── ARQUITETURA-MANIFESTOS.md
│       ├── ENTREGA.md
│       └── manifestos-arquitetura.html
└── README.md
```

### Princípios de Arquitetura (k8s/base/)
- **DRY**: um YAML por recurso, sem duplicação entre `base/` e `helm/`
- **Camadas**: namespace → config → database → app → network → cleanup
- **GitOps Ready**: `kustomization.yaml` aponta para arquivos existentes em `base/`
- **Manutenção Elegante**: nomes semânticos, sem prefixos numéricos artificiais

## Autenticação ArgoCD → GitHub

- `argocd_repo_credentials` (terraform/null_resource) cria secret `argocd-repo-nikolastsdev` no namespace `argocd`
- Usa `gh auth token` para autenticar repo privado
- `imagePullSecret ghcr-pull` criado no namespace `todolist` para acessar `ghcr.io`

## Pipeline CI (unificado — `ci.yaml`)

- `.github/workflows/ci.yaml`: pipeline único em 4 jobs — `test` (Python + PostgreSQL), `build` (Build+Push GHCR), `scan` (Trivy), `deploy` (GitOps mono-repo, promove imagem no manifest `k8s/base/app/deployment.yaml`).
- `context: app/todolist`; `file: app/todolist/Dockerfile`; `permissions: packages: write`; dispara em `push main`.
- Imagem: `ghcr.io/nikolastsdev/platform-engineer/todolist:latest`

## Notes

- `terraform/main.tf` usa `null_resource` + `local-exec` (não usa kubernetes/helm providers — kubeconfig só existe após `kind_cluster` ser criado)
- `kind_config` usa `kubeconfig_path = pathexpand("~/.kube/kind-todolist-platform.conf")`
- O `Dockerfile` usa `python:3.11-slim`; app roda em porta 5000 (gunicorn)
