# 🏗️ Arquitetura do Projeto — todolist-app Platform

Diagramas Mermaid (renderiza no GitHub automaticamente) + Draw.io editável.

## 📑 Índice

- [Estado Atual (as-is)](./arquitetura-as-is.md) — `docs/diagrams/arquitetura-as-is.md`
- [Estado Ideal (to-be)](./arquitetura-to-be.md) — `docs/diagrams/arquitetura-to-be.md`
- [Modelo C4 (Context, Container, Component)](./modelo-c4.md) — `docs/diagrams/modelo-c4.md`
- [Draw.io editável](./arquitetura.drawio) — abrir em https://app.diagrams.net

## 🎯 Diagrama principal — Visão geral to-be

```mermaid
flowchart TB
    subgraph EXT["🌐 EXTERNO"]
        USER["👤 Usuário"]
        DEV["💻 Dev"]
    end

    subgraph CI["⚙️ CI/CD"]
        GHA["GitHub Actions"]
        IMG["📦 ghcr.io/.../todolist-app"]
    end

    subgraph OPS["🛠️ GITOPS"]
        FLUX["⚙️ Flux CD"]
        HR["🎯 HelmRelease"]
    end

    subgraph CL["☸️ KIND CLUSTER"]
        NGINX["🌐 NGINX Ingress"]
        subgraph APP_NS["Namespace: todolist"]
            APP["📦 Deployment\n(HPA 2-10, PDB 1)"]
            SVC["🎯 Service"]
            CRON["⏰ CronJob cleanup"]
            SA["🔑 ServiceAccount"]
            SEC["🤫 Secret"]
        end
        subgraph DB_NS["Namespace: todolist-db"]
            PG["🐘 PostgreSQL"]
        end
        subgraph INFRA["Namespace: ingress-nginx"]
            IC["NGINX Controller"]
        end
    end

    subgraph OBS["📡 OBSERVABILITY"]
        PROM["📈 Prometheus"]
        GRAF["📊 Grafana"]
    end

    DEV -->|push| GHA --> IMG --> FLUX --> HR
    HR --> APP & CRON & SEC
    APP --> SVC --> NGINX
    APP --> PG
    APP -.->|scrapes| PROM --> GRAF
    USER -->|http:8080| NGINX
```

## 🛡️ Decisões arquiteturais

- [ADR-0001: Cluster local (Kind)](../adr/0001-cluster-local-kind.md)
- [ADR-0002: Terraform como IaC](../adr/0002-terraform-iac.md)
- [ADR-0003: Helm como package manager](../adr/0003-helm-package-manager.md)
- [ADR-0004: GitOps com Flux CD](../adr/0004-gitops-flux-cd.md)
- [ADR-0005: NGINX como Ingress](../adr/0005-nginx-ingress.md)
- [ADR-0006: HPA + PDB para resiliência](../adr/0006-hpa-pdb-resiliencia.md)
- [ADR-0007: GHCR para imagens](../adr/0007-ghcr-imagens.md)
- [ADR-0008: Trivy para vulnerability scanning](../adr/0008-trivy-scan.md)

## 🧭 Navegação rápida

- [README principal](../../README.md)
- [Decisões gerais](../DECISOES.md)
- [ADRs formais](../adr/)
