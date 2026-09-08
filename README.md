# Platform Engineer Challenge

> **Escopo:** Desafio técnico DevOps / Platform Engineer. Foco exclusivo nos requisitos R1–R5 do PDF (`DESAFIO-PLATFORM-ENGINEER.pdf`): provisão por código, deploy automatizado, acesso externo, escalabilidade/resiliência e documentação. Nada além do que os requisitos pedem (ver [Registro de Decisões](docs/decisoes/escopo-decisoes.md)).

## Índice

- [Visão geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Requisitos atendidos](#requisitos-atendidos)
- [Pré-requisitos](#pré-requisitos)
- [Execução](#execução)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Pipeline CI/CD](#pipeline-cicd)
- [Acesso à aplicação](#acesso-à-aplicação)
- [Escalabilidade e resiliência](#escalabilidade-e-resiliência)
- [Registro de decisões](#registro-de-decisões)
- [Evidências de execução](#evidências-de-execução)

---

## Visão geral

**O que é:** ambiente Kubernetes local com deploy automatizado via GitOps (ArgoCD).

- **Cluster:** Kind (4 nodes, Kubernetes v1.30.0), provisionado com Terraform via `make create`
- **Deploy:** ArgoCD sincroniza a aplicação a partir do Helm chart no repositório
- **Aplicação:** Flask + PostgreSQL, acessível em `http://localhost/`
- **Escopo:** apenas os requisitos R1–R5 do PDF (sem extras)

Rodar tudo é `make create` (sobe o ambiente) e `make destroy` (remove). O Makefile apenas encurta as chamadas de `terraform`/`kubectl`.

---

## Arquitetura

[![Arquitetura (archify)](docs/arquitetura/arquitetura.html)](docs/arquitetura/arquitetura.html)

**Fluxo:** o código da aplicação e do Helm chart ficam no repositório; o ArgoCD aplica o que está no `k8s/helm/todolist-app` e o CI atualiza a versão da imagem no `values.yaml`. Diagrama interativo (pan/zoom/busca, exporta PNG/SVG): `docs/arquitetura/arquitetura.html` (dados em `arquitetura.json`).

### Divisão de responsabilidades

| Etapa | Ferramenta | Onde roda |
|-------|-----------|-----------|
| Provisionamento (cluster + deps) | Terraform + Kind + Helm | CLI local (`make create`) |
| Build da imagem | Docker / build-push-action | GitHub Actions (`.github/workflows/ci.yaml`) |
| Deploy da aplicação | ArgoCD (GitOps sync) | ArgoCD + Helm chart no repo (mono-repo) |

### Por que Kind local (em vez de cloud)?

O desafio foi feito em ambiente local com **Kind** por questões de billing e faturamento da cloud. O funcionamento é o mesmo de um cluster real: Terraform provisiona os recursos, ArgoCD aplica via GitOps e o ingress expõe a aplicação externamente. Detalhes e argumentos completos no [registro de decisões](docs/decisoes/escopo-decisoes.md#ambiente-kind-local-em-vez-de-cloud-eksgke).

---

## Requisitos atendidos

| Req | Descrição | Como é atendido |
|-----|-----------|-----------------|
| **R1** | Cluster e dependências provisionados por código, repetível | `terraform/` + `make create` (Kind, ingress-nginx, metrics-server, ArgoCD) |
| **R2** | Deploy automático de nova versão da app | ArgoCD sincroniza `k8s/helm/todolist-app` a partir do repositório |
| **R3** | Acesso pelo navegador, fora do cluster | Ingress nginx expõe a app em `http://localhost/` |
| **R4** | Escalável e resiliente | HPA, PodDisruptionBudget e probes no chart (`hpa.yaml`, `pdb.yaml`, `deployment.yaml`) |
| **R5** | Documentação, decisões e evidências de execução | Este README + `docs/decisoes/` + `docs/evidencias/` |

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

## Execução

```bash
make create    # sobe todo o ambiente (3-5 min)
make destroy   # remove todo o ambiente
```

Acesso pela máquina local:

- Aplicação: `http://localhost/`
- ArgoCD: `https://localhost:8080` (NodePort 30080 → porta 8080 do host)

O `make create` executa `terraform init + apply` e provisiona cluster, ingress-nginx, metrics-server, ArgoCD e namespaces. Tudo por código.

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
│   └── helm/todolist-app/         # Helm chart (ArgoCD sync)
│       ├── Chart.yaml, values.yaml, values.schema.json
│       └── templates/             # namespace, deployment, service, ingress, hpa, pdb, ...
├── app/todolist/                  # Aplicação Flask (Dockerfile, app.py, requirements.txt)
├── docs/
│   ├── arquitetura/               # Diagrama único da arquitetura (archify: arquitetura.html + .json)
│   ├── decisoes/
│   │   └── escopo-decisoes.md     # Registro de decisões (argumentos, o que descartou)
│   └── evidencias/                # Evidências reais de execução
├── scripts/                       # Auxiliares de operação
├── Makefile                       # create / destroy / clean
└── README.md                      # Este arquivo
```

---

## Pipeline CI/CD

Pipeline em 4 etapas (`.github/workflows/ci.yaml`) — só um ambiente local:

```
test  →  build  →  scan  →  deploy
```

- **test:** testes da aplicação (Python + PostgreSQL)
- **build:** build + push da imagem para GHCR (`ghcr.io/nikolastsdev/platform-engineer/todolist:latest`)
- **scan:** Trivy (análise de vulnerabilidades)
- **deploy:** atualiza a versão da imagem no `values.yaml` do chart; o ArgoCD detecta a mudança no repositório e aplica ao cluster

---

## Acesso à aplicação

- Aplicação: `http://localhost/` (redirect para `/login`)
- ArgoCD: `https://localhost:8080` (NodePort 30080, exposto na porta 8080 do host)
- Senha inicial do ArgoCD:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Portas expostas pelo Kind no host: 80 / 443 (ingress) e 8080 (ArgoCD).

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
