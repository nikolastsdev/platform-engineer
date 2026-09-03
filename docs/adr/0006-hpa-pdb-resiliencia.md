# ADR 0006: HPA + PDB para resiliência

## Status
**Aprovado**

## Contexto
A aplicação precisa ser escalável e resiliente (R4). Isso significa: (1) escalar sob demanda, (2) sobreviver a updates sem downtime, (3) manter disponibilidade durante disruptions voluntárias.

## Decisão
Usar:
- **HorizontalPodAutoscaler (HPA v2)** — escala 2 a 10 réplicas baseado em CPU (70%) e Memória (80%)
- **PodDisruptionBudget (PDB)** — garante que pelo menos 1 pod esteja disponível durante updates
- **RollingUpdate strategy** — maxSurge: 1, maxUnavailable: 0
- **Probes** — liveness (reinicia pods travados), readiness (remove do balanceamento), startup (protege inicialização lenta)

## Consequências

- ✅ Autoscaling reativo a carga
- ✅ Zero-downtime deploys
- ✅ Failover durante draining de nodes
- ❗ HPA precisa Metrics Server (instalado via Terraform)
- ❗ Pods semafinidade/distribuição podem acumular no mesmo node
