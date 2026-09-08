# ADR 0008: Trivy para vulnerability scanning

## Status
**Aprovado**

## Contexto
Segurança é parte das boas práticas de mercado (requisito do desafio, seção 6). Precisamos detectar vulnerabilidades conhecidas (CVEs) na imagem Docker antes de deployar.

## Decisão
Integrar [Aqua Security Trivy](https://trivy.dev/) na pipeline CI. Trivy escaneia a imagem (layer por layer) para CVEs e falha o build se encontrar vulnerabilidades HIGH ou CRITICAL.

## Consequências

- ✅ Scan gratuito, rápido (segundos), integrado ao GitHub Actions
- ✅ Suporte a imagens OCI, SBOM, vulnerabilidades
- ❗ Base `python:3.11-slim` tinha CVEs → corrigido para `python:3.13-slim` (`Dockerfile` atual, push `8097868`).
- ✅ Pipeline `scan` agora passa com base atualizada; `deploy` (GitOps) pode rodar.
