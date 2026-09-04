# Platform Engineer Challenge

Pipeline CI/CD local com **Terraform + Kind + ArgoCD (GitOps)** para deploy automatizado de uma aplicação Flask com PostgreSQL.

> Atualizado: `make create` / `make destroy` (não `make up`); `todolist-app/` como pasta normal (não submódulo); CI via `.github/workflows/build.yaml`; imagem `ghcr.io/nikolastsdev/platform-engineer/todolist:latest`; nome do usuário atualizado para **Nikolas Schaffer**.

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
│  │ build.yaml     │          │  ├─ todolist-db (PG)     │         │
│  └────────────────┘          │  └─ app (3 pods)        │         │
│                              └────────────────────────┘         │
└───────────────────────────────────────────────────────────────────┘
```

## Divisão de Responsabilidades

| Etapa | Ferramenta | Onde roda |
|-------|-----------|-----------|
| Provisionamento (cluster + deps) | Terraform + Kind + Helm | CLI local (`make create`) |
| Build da imagem | Docker / build-push-action | GitHub Actions (`.github/workflows/build.yaml`) |
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
├── terraform/                 # IaC (kind, ingress, metrics, argocd, namespaces)
│   ├── main.tf                # null_resource + local-exec (kubeconfig via kind)
│   ├── argocd.tf              # repo credentials (PAT via gh auth token)
│   ├── variables.tf           # argocd_repo_owner, argocd_repo_name
│   ├── providers.tf           # kind + null
│   └── outputs.tf             # app_namespace, kubeconfig_path
├── todolist-app/              # App Flask (pasta normal, não submódulo)
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── .github/workflows/
│   └── build.yaml             # Build + Push para GHCR (login via GITHUB_TOKEN)
├── Makefile                   # create / destroy / clean
├── k8s/base/                  # Manifests GitOps (ArgoCD sync)
└── README.md
```

## Autenticação ArgoCD → GitHub

- `argocd_repo_credentials` (terraform/null_resource) cria secret `argocd-repo-nikolastsdev` no namespace `argocd`
- Usa `gh auth token` para autenticar repo privado
- `imagePullSecret ghcr-pull` criado no namespace `todolist` para acessar `ghcr.io`

## Pipeline CI (funcionando)

- `.github/workflows/build.yaml`: `workflow_dispatch` + `push`; `context: .`; `file: ./todolist-app/Dockerfile`; `permissions: packages: write`
- Build passa: `completed success` (run `33823052362`)
- Imagem: `ghcr.io/nikolastsdev/platform-engineer/todolist:latest`

## Notes

- `terraform/main.tf` usa `null_resource` + `local-exec` (não usa kubernetes/helm providers — kubeconfig só existe após `kind_cluster` ser criado)
- `kind_config` usa `kubeconfig_path = pathexpand("~/.kube/kind-todolist-platform.conf")`
- O `Dockerfile` usa `python:3.11-slim`; app roda em porta 5000 (gunicorn)
