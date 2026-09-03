# Platform Engineer Challenge

Pipeline CI/CD local com **Terraform + Kind + ArgoCD (GitOps)** para deploy automatizado de uma aplicação Flask com PostgreSQL.

## Arquitetura

```
┌───────────────────────────────────────────────────────────────────┐
│  Host Machine (Linux)                                            │
│                                                                   │
│  ┌─────────────────┐     ┌──────────────────────────────────┐   │
│  │  make up (CLI)  │────▶│  Terraform (providers: kind,     │   │
│  │  Terraform       │     │  helm, kubernetes, docker)       │   │
│  └─────────────────┘     └──────────────────────────────────┘   │
│         │                            │                            │
│         │               ┌────────────┴────────────────┐         │
│         │               │ 1. kind-registry :5000      │         │
│         │               │ 2. kind cluster             │         │
│         │               │    ├─ control-plane         │         │
│         │               │    ├─ worker ×3             │         │
│         │               │    ├─ ingress-nginx (NodePort)       │
│         │               │    └─ metrics-server        │         │
│         │               │ 3. ArgoCD (Helm)            │         │
│         │               │    └─ Application: todolist │         │
│         │               └─────────────────────────────┘         │
│         │                            │                            │
│  ┌──────┴─────────┐          ┌───────┴───────────────┐         │
│  │ GitHub Actions │          │  kind cluster          │         │
│  │ (self-hosted)  │          │  ┌──────────────────┐  │         │
│  │                │          │  │ todolist namespace│  │         │
│  │ jobs:          │───────┐  │  │  ├─ App (3 pods) │  │         │
│  │  test          │       │  │  │  ├─ HPA (2-10)   │  │         │
│  │  build+push    │       │  │  │  ├─ CronJob      │  │         │
│  │  scan (trivy)  │       │  │  │  └─ Ingress      │  │         │
│  │  deploy (sync) │       │  │  └──────────────────┘  │         │
│  └────────────────┘       │  │  ┌──────────────────┐  │         │
│                           │  │  │ todolist-db ns   │  │         │
│                           │  │  │  └─ PostgreSQL 15│  │         │
│                           │  │  └──────────────────┘  │         │
│                           │  └────────────────────────┘         │
│                           └───────────────────────────────────────┘
└───────────────────────────────────────────────────────────────────┘
```

## Divisão de Responsabilidades

| Etapa | Ferramenta | Onde roda |
|-------|-----------|-----------|
| Provisionamento (cluster + deps) | Terraform + Kind + Helm | CLI local (`make up`) |
| Build da imagem | Docker | GitHub Actions (self-hosted runner) |
| Testes (Python + Postgres) | pytest / import check | GitHub Actions (self-hosted runner) |
| Security scan | Trivy | GitHub Actions (self-hosted runner) |
| Deploy da aplicação | ArgoCD (GitOps sync) | GitHub Actions + ArgoCD |

## Pré-requisitos

```bash
# Ferramentas obrigatórias
docker --version      # Docker daemon rodando
kind --version        # Kubernetes IN Docker
kubectl version       # CLI do Kubernetes
terraform --version   # Infrastructure as Code
helm version          # Package manager do Kubernetes
```

> **Java 17+** é necessário apenas para rodar o GitHub Actions runner (`scripts/setup-runner.sh`).

## Setup Rápido

### 1. Setup completo (recomendado)

```bash
make setup
# ou, explicitamente:
./scripts/setup.sh
```

Isso executa:
1. `make up` → Terraform: registry + cluster kind + ingress + metrics-server + ArgoCD
2. Build + push da imagem da app para `localhost:5000`
3. Força sync do ArgoCD (GitOps)

### 2. Apenas provisionar a infraestrutura

```bash
make up
```

Cria: `kind-registry`, cluster `todolist-platform`, NGINX Ingress, metrics-server, ArgoCD + Application GitOps.

### 3. Verificar saúde

```bash
make verify
# ou:
./scripts/verify.sh
```

## URLs de Acesso

| Serviço | URL |
|---------|-----|
| Aplicação Flask | `http://localhost` |
| ArgoCD UI | `http://localhost:30080` |
| App API (healthz) | `http://localhost/healthz` |

**Credenciais padrão (local):**
- App: `admin` / `admin123`
- ArgoCD: `admin` / `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`

## Pipeline CI/CD (GitHub Actions)

A pipeline em `.github/workflows/ci.yaml` roda no **self-hosted runner** registrado localmente.

### Triggers

- **`push to main`** → build + test + scan + deploy via ArgoCD
- **`PR to main`** → test apenas (sem deploy)

### Jobs

| Job | Descrição | Requer push main? |
|-----|-----------|--------------------|
| `test` | Import check com Python 3.11 + PostgreSQL service | Não |
| `build` | Build imagem Docker, push para `localhost:5000` | Sim |
| `scan` | Trivy (CRITICAL/HIGH fails build) | Sim |
| `deploy` | Força sync ArgoCD → GitOps aplica os manifests | Sim |

### Setup do runner local

```bash
# Token de registro (obtido em: Settings > Actions > Runners)
REPO_URL=https://github.com/seu-usuario/seu-repo \
RUNNER_TOKEN=<token> \
make setup-runner
# ou:
./scripts/setup-runner.sh
```

## Estrutura do Repositório

```
├── terraform/                 # IaC — provisionamento via `make up`
│   ├── providers.tf           # Kind + Kubernetes + Helm + Docker
│   ├── main.tf                # Registry + Ingress + Metrics + ArgoCD
│   ├── variables.tf
│   └── outputs.tf
│
├── k8s/
│   ├── base/                  # Manifests GitOps (sincronizados pelo ArgoCD)
│   │   ├── 00-namespace.yaml
│   │   ├── 01-configmap.yaml
│   │   ├── 01-secret.yaml
│   │   ├── 02-postgresql.yaml
│   │   ├── 03-app.yaml
│   │   ├── 04-ingress.yaml
│   │   ├── 05-rbac.yaml
│   │   ├── 05-cronjob.yaml
│   │   └── kustomization.yaml
│   └── helm/
│       └── todolist-app/      # Helm chart para deploy manual via CLI
│           ├── Chart.yaml
│           ├── values.yaml
│           └── templates/
│
├── todolist-app/              # App Flask
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── .github/workflows/
│   └── ci.yaml                # Pipeline: test + build + scan + deploy
│
├── scripts/
│   ├── setup.sh               # Setup completo (make up + build + sync)
│   ├── teardown.sh            # Remove toda a infra
│   ├── verify.sh              # Health checks
│   └── setup-runner.sh        # Instala GitHub Actions runner local
│
├── Makefile
├── .gitignore
└── README.md
```

## Comandos Úteis

```bash
# Provisionar infraestrutura
make up          # terraform init + apply (registry + cluster + deps)
make down        # terraform destroy

# Deploy da aplicação
make setup       # make up + build/push imagem + ArgoCD sync

# Verificação
make verify      # Health checks completos

# Runner local
make setup-runner # Instala e registra GitHub Actions runner

# Helm chart (deploy manual)
helm upgrade --install todolist-app ./k8s/helm/todolist-app \
  --namespace todolist --create-namespace \
  --set autoscaling.enabled=false

# Teardown completo
make teardown    # destroy + limpeza
```

## Arquitetura Decision Records (ADRs)

| ADR | Decisão |
|-----|---------|
| ADR-001 | KIND para cluster local |
| ADR-002 | Terraform para IaC |
| ADR-003 | NGINX Ingress Controller |
| ADR-004 | PostgreSQL com emptyDir |
| ADR-005 | HPA v2 (CPU 70%, Mem 80%) |
| ADR-006 | Registry Docker local |
| ADR-007 | CronJob para limpeza |
| ADR-008 | Estrutura GitOps-ready |
| ADR-009 | ServiceAccount com RBAC mínimo |
| ADR-010 | Trivy para security scan |

Ver detalhes em [docs/adr/](docs/adr/).

## Melhorias Futuras

- [ ] TLS via cert-manager (Let's Encrypt)
- [ ] Prometheus + Grafana (monitoring)
- [ ] Velero (backups)
- [ ] SealedSecrets (secret management)
- [ ] Network Policies (micro-segmentation)
