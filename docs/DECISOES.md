# Registro de Decisões

## Data: 2025-09-03

### 1. Por que Kind ao invés de cloud?
Baseado no PDF `DESAFIO-PLATFORM-ENGINEER.pdf`: "Onde rodar fica a seu critério... desde que seja um ambiente Kubernetes." Kind atende perfeitamente.
O desafio permite "localmente, desde que seja Kubernetes". Kind oferece:
- Nenhum custo de cloud
- Criação/destroção em segundos
- Mesma API Kubernetes
- Replicável em qualquer máquina com Docker

**Descartado:** AWS EKS, GKE, AKS — adicionariam latência e custo sem ganho técnico para o escopo.

### 2. Por que Terraform?
Terraform é declarativo, versionado e permite `terraform apply` repetível. Já havia arquivos no diretório (`terraform/`), aproveitados com ajustes.

### 3. Por que Helm?
O `todolist-app` precisa de container, service, ingress, HPA. Helm permite parametrizar tudo sem duplicar YAML.

### 4. Por que Flux ao invés de ArgoCD?
Flux (GitOps) é mais leve e nativo em Kubernetes. O deploy é automático ao fazer `git push` no repo de manifests.

### 5. Escalabilidade: HPA + PDB
- HPA (`autoscaling/v2`) escala pods baseado em CPU/memória
- PDB (`PodDisruptionBudget`) garante que pelo menos 1 pod esteja disponível durante atualizações

### 6. Resiliência: Probes
- `livenessProbe` detecta aplicação travada
- `readinessProbe` remove o pod do service se não estiver pronto
- `startupProbe` protege inicialização lenta

### 8. Plugin mermaid para renderização
Criado `dsh-plugin-mermaid/` — plugin que registra `mermaidRenderer` no cordis do DSH, com CLI `dsh-render-md` (PNG/SVG) e `dsh-md-preview` (servidor local com Mermaid.js CDN).
O README é o índice. `docs/DECISOES.md` explica o "porquê". `docs/DESAFIOS.md` registra obstáculos.
