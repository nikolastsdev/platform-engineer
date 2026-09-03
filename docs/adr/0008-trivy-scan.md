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
- ❗ Falsos positivos podem ocorrer (exige `trivy ignore`)
- ❗ Só detecta vulnerabilidades conhecidas (não bugs de aplicação)
