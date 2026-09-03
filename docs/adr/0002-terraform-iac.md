# ADR 0002: Terraform como IaC

## Status
**Aprovado**

## Contexto
Precisa-se de provisionamento repetível e versionado para o cluster Kind e suas dependências (registry, ingress, metrics server, namespace).

## Decisão
Usar Terraform com o provider `kyoh86/kind` para criar o cluster Kind e o provider `kreuzwerker/docker` para o registry local. Helm provider gerencia NGINX Ingress e Metrics Server.

## Consequências

- ✅ Declarafivo, versionável, idempotente
- ✅ Providers verificados: `kyoh86/kind` (~0.2), `hashicorp/helm` (~2.12), `kreuzwerker/docker` (~3.0)
- ❗ Terraform `local-exec` provisioners são imperativos (trade-off aceito)
- ❌ `terraform apply` para Kind é mais lento que `kind create cluster` direto
