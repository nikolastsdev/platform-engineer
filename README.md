# Platform Engineer Challenge

> **Escopo:** Desafio técnico DevOps / Platform Engineer. Foco exclusivo nos requisitos R1–R5 do PDF (`DESAFIO-PLATFORM-ENGINEER.pdf`): provisão por código, deploy automatizado, acesso externo, escalabilidade/resiliência e documentação. Nada além do que os requisitos pedem (ver [Registro de Decisões](docs/decisoes/escopo-decisoes.md)).

## Índice

- [Visão geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Requisitos atendidos](#requisitos-atendidos)
- [Pré-requisitos](#pré-requisitos)
- [Execução (como rodar)](#execução-como-rodar)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Pipeline CI/CD](#pipeline-cicd)
- [Acesso à aplicação](#acesso-à-aplicação)
- [Escalabilidade e resiliência](#escalabilidade-e-resiliência)
- [Registro de decisões](#registro-de-decisões)
- [Evidências de execução](#evidências-de-execução)

---

## Visão geral

**O que é:** pipeline local, código puro — nenhum clique no console.
- **Cluster:** Kind (4 nodes, K8s v1.30.0) via Terraform
- **Deploy:** ArgoCD (GitOps) sincroniza `k8s/helm/todolist-app`
- **App:** Flask + PostgreSQL, acessível em `http://localhost/`
- **Escopo:** apenas R1–R5 do PDF (sem extras)

**Como funciona em 3 passos:** `make create` → `make destroy`. Tudo no `Makefile`.

---

## Arquitetura

[![Arquitetura (archify)](docs/arquitetura-manifestos/manifestos-arquitetura.html)](docs/arquitetura-manifestos/manifestos-arquitetura.html)

**Diagrama interativo atualizado** com CI + PostgreSQL → `docs/arquitetura-manifestos/manifestos-arquitetura.html` (pan/zoom/busca/exporta PNG/SVG). Dados: `manifestos-arquitetura.json`. Componentes: Repo Git → Helm chart (fonte única) → ArgoCD (GitOps) → Kind Cluster (4 nodes) → PostgreSQL + todolist-app; CI promove tag no values.

### Divisão de responsabilidades

| Etapa | Ferramenta | Onde roda |
|-------|-----------|-----------|
| Provisionamento (cluster + deps) | Terraform + Kind + Helm | CLI local (`make create`) |
| Build da imagem | Docker / build-push-action | GitHub Actions (`.github/workflows/ci.yaml`) |
| Deploy da aplicação | ArgoCD (GitOps sync) | ArgoCD + Helm chart no repo (mono-repo) |

### Por que Kind local (em vez de cloud)?

Não há disponibilidade de serviço de cloud por burocracia de billing/faturamento. A escolha foi um laboratório local usando **Kind**, recomendado pela [documentação oficial do Kubernetes](https://kind.sigs.k8s.io/). O GitOps é mantido (Git como fonte de verdade); a infra é provisionada via CLI por ser ambiente local. Detalhes no [registro de decisões](docs/decisoes/escopo-decisoes.md#ambiente-kind-local-em-vez-de-cloud-eksgke).

---

## Requisitos atendidos

| Req | Descrição | Como é atendido | Onde |
|-----|-----------|-----------------|------|
| **R1** | Cluster + infra por código | `terraform/` + `make create` |
| **R2** | Deploy automatizado | `k8s/helm/` (ArgoCD sync) |
| **R3** | Acesso externo | `ingress.yaml` (`localhost`) |
| **R4** | Escala + resiliência | `hpa.yaml`, `pdb.yaml`, `deployment.yaml` |
| **R5** | Documentação | Este README + `docs/decisoes/` + `docs/evidencias/` |

---

## Pré-requisitos

- Linux (testado em Ubuntu)
- [Docker](https://docs.docker.com/get-docker/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.x)
- [Helm](https://helm.sh/docs/intro/install/) (>= 3.x)
- [gh](https://cli.github.com/) CLI autenticado (para o CI/build GHCR)

---

## Execução (como rodar)

```bash
make create    # provisiona tudo (3-5 min)
make destroy   # limpa tudo
curl http://localhost/        # app
curl -k https://localhost/ -H "Host: argocd.localhost"  # ArgoCD
```

> Nenhum passo manual no console — só `make create`.

---

## Estrutura do repositório

```
├── terraform/                     # IaC (kind, ingress, metrics, argocd)
│   ├── main.tf                    # cluster kind + kubeconfig
│   ├── argocd.tf                  # repo credentials (PAT via gh auth token)
│   ├── variables.tf / providers.tf / outputs.tf
├── .github/workflows/
│   └── ci.yaml                    # Test → Build+Push GHCR → Scan → Deploy GitOps
├── k8s/
│   └── helm/todolist-app/         # ⭐ FONTE ÚNICA — Helm chart (ArgoCD sync)
│       ├── Chart.yaml, values.yaml, values.schema.json
│       └── templates/             # namespace, deployment, service, ingress, hpa, pdb, ...
├── app/todolist/                  # Aplicação Flask (Dockerfile, app.py, requirements.txt)
├── docs/
│   └── decisoes/
│       └── escopo-decisoes.md     # Registro de decisões (argumentos, o que descartou)
├── scripts/                       # Auxiliares de operação
├── Makefile                       # create / destroy / clean
└── README.md                      # Este arquivo
```

---

## Pipeline CI/CD

Pipeline única (`.github/workflows/ci.yaml`) — 4 jobs, foco nos requisitos (single ambiente local):

```
test  →  build  →  scan  →  deploy
(Python + (Build+Push  (Trivy  (GitOps: promove imagem
 Postgres)  GHCR)        scan)    no values.yaml → ArgoCD sync)
```

- **test:** testes da aplicação (Python + PostgreSQL)
- **build:** build + push da imagem para GHCR (`ghcr.io/nikolastsdev/platform-engineer/todolist:latest`)
- **scan:** Trivy (análise de vulnerabilidades)
- **deploy:** atualiza o `values.yaml` do Helm chart com a nova imagem — o ArgoCD sincroniza automaticamente (GitOps mono-repo)

> **Detalhe GitOps:** o deploy da app é feito pelo ArgoCD apontando para `k8s/helm/todolist-app/` no repositório. O CI apenas promove a versão no Git (fonte de verdade); o ArgoCD (com self-healing) aplica ao cluster.

---

## Acesso à aplicação

- `http://localhost/` → app (`/login`)
- `https://localhost/` + `Host: argocd.localhost` → ArgoCD
- ArgoCD senha: `kubectl get secret argocd-initial-admin-secret ... | base64 -d`

Portas expostas pelo Kind: 80 / 443 / 30080.

---

## Escalabilidade e resiliência

- **HPA (HorizontalPodAutoscaler):** escala o número de réplicas com base na utilização de CPU/memória (`hpa.yaml`)
- **PDB (PodDisruptionBudget):** garante disponibilidade mínima durante manutenções/drenagens (`pdb.yaml`)
- **Réplicas parametrizáveis:** configuração via `values.yaml` (`replicaCount`)
- **Healthchecks:** readiness/liveness probes no `deployment.yaml`
- **PostgreSQL:** deployado como deployment + service + secret no mesmo chart (`postgresql.yaml`)

---

## Registro de decisões

Ver [docs/decisoes/escopo-decisoes.md](docs/decisoes/escopo-decisoes.md) — inclui o argumento da escolha do ambiente Kind local, a pipeline simplificada, o que foi descartado e as ferramentas de apoio ao desenvolvimento.

> **Ferramentas de apoio:** este projeto foi desenvolvido com apoio de IA via **DeepSeek Harness (DSH)** como ambiente de agente e **Omniroute** ([github.com/diegosouzapw/OmniRoute](https://github.com/diegosouzapw/OmniRoute)) como gateway de IA (tokens gratuitos / modelos free) — uso liberado pelo desafio (PDF, seção 3). Detalhes em [docs/decisoes/escopo-decisoes.md](docs/decisoes/escopo-decisoes.md#ferramentas-de-apoio-ao-desenvolvimento-e-por-que).

---

## Evidências de execução

Artefatos reais gerados na execução (ver `docs/evidencias/`):

| Evidência | Arquivo | O que prova |
|-----------|---------|-------------|
| Log completo do provisionamento (`make create`) | `docs/evidencias/log-make-create.txt` | R1/R2 — cluster + ingress + ArgoCD provisionados por código, sem passos manuais |
| Resumo kubectl (nodes, pods, app, ingress) | `docs/evidencias/resumo-kubectl.txt` | R1/R4 — 4 nodes Ready, ArgoCD Synced/Healthy, app 2/2 Running |
| Acesso externo via curl (R3) | `docs/evidencias/curl-acesso.txt` | App HTTP 302→200 em `http://localhost`, ArgoCD HTTP 200 |
| Página de login da app renderizada | `docs/evidencias/app-login.html` | O que o navegador renderiza (R3) |

Evidências (logs, curl, HTML, kubectl): `docs/evidencias/`. Nenhum print de navegador — execução via CLI apenas.
