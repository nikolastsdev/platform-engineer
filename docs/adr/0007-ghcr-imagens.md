# ADR 0007: GHCR para imagens

## Status
**Aprovado (to-be)**

## Contexto
Hoje a aplicação usa um registry local (`localhost:5000`). Para CI/CD e compartilhamento de imagens, precisamos de um registry remoto.

## Decisão
Usar [GitHub Container Registry (GHCR)](https://ghcr.io) integrado ao repo. A pipeline `ci-cd.yaml` faz login via `GITHUB_TOKEN`, build com BuildKit e push.

## Consequências

- ✅ Nenhum serviço externo extra (integrado ao GitHub)
- ✅ Scanner de vulnerabilidades integrado (Dependabot)
- ✅ Pull anônimo permitido (sem autenticação de consumidor)
- ❗ Imagens são públicas (se o repo for público)
