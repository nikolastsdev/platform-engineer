# ADR 0004: GitOps com Flux CD

## Status
**Aprovado (to-be)**

## Contexto
Deployments manuais (`helm upgrade` via CLI) não são escaláveis, auditáveis nem rollback-áveis. Para produção, queremos **Git como fonte única da verdade**: o estado do cluster é derivado do que está commitado.

## Decisão
Adicionar [Flux CD](https://fluxcd.io/) ao cluster. Flux monitora o repositório Git, detecta mudanças no Helm chart e aplica automaticamente (GitOps).

### Componentes
- `GitRepository` — fonte (URL do repo)
- `Kustomization` — sincronização
- `HelmRelease` — release de Helm
- `ImageRepository` + `ImagePolicy` — automatização de tags de imagem

## Consequências

- ✅ Estado do cluster auditável (git history)
- ✅ Rollback = `git revert`
- ✅ Image Automation atualiza a tag da imagem automaticamente
- ❗ Mais peças para configurar
- ❗ Tempo de adaptação para o time
