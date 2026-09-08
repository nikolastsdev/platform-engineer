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

### 4. Por que ArgoCD ao invés de Flux?
ArgoCD é o GitOps implementado neste projeto (via Helm chart + `argocd_app_todolist` em `terraform/main.tf`). Oferece UI de sync status (`Synced`/`Healthy`), rollback visual e integração direta com repositórios privados via PAT (`gh auth token`).
Flux seria uma alternativa válida, mas o desafio já continava infraestrutura ArgoCD (`terraform/argocd.tf`) e a documentação do projeto já referenciava `argo-test-manifests` como repo de manifests. Manter ArgoCD evita retrabalho.
**Descartado:** Flux (seria uma migração sem ganho no escopo definido).

### 5. Escalabilidade: HPA + PDB
- HPA (`autoscaling/v2`) escala pods baseado em CPU/memória
- PDB (`PodDisruptionBudget`) garante que pelo menos 1 pod esteja disponível durante atualizações
- Ambas em `k8s/base/app.yaml` (HPA) e `k8s/base/pdb.yaml` (PDB); Helm chart em `k8s/helm/` é template de referência (não usado no fluxo GitOps)

### 6. Resiliência: Probes
- `livenessProbe` detecta aplicação travada
- `readinessProbe` remove o pod do service se não estiver pronto
- `startupProbe` protege inicialização lenta

### 7. Helm chart como fonte única de manifestos
- `k8s/helm/todolist-app/`: Helm chart parametrizável — **única** fonte de recursos (app, postgres, network, cleanup, namespaces).
- **Histórico:** inicialmente havia também `k8s/base/` (Kustomize com YAMLs estáticos), duplicando o Helm. Decidido remover a duplicação: Helm é a fonte, o ArgoCD aponta direto para o chart (`path: k8s/helm/todolist-app`).
- Decisão: ArgoCD aponta para o Helm chart (auto-detect via `Chart.yaml`) para manter GitOps declarativo, DRY e simples.

### 8. PostgreSQL sem persistência (emptyDir)
O banco PostgreSQL (`templates/postgresql.yaml` no Helm chart) usa `emptyDir` — dados são perdidos em restart.
Isso é **aceitável para o escopo local do desafio**: reduz complexidade e custo, e o PDF não exige persistência.
Em produção, usaríamos PersistentVolumeClaim (ex: `hostPath` para Kind ou `StorageClass` em cloud).

### 9. Repositório GitOps: mono-repo
O repositório de aplicação (`nikolastsdev/platform-engineer`) também contém o Helm chart (`k8s/helm/todolist-app/`).
Isso simplifica: um único repo para CI + GitOps.
**Alternativa considerada:** Repo separado de manifests (ex: `nikolastsdev/argo-test-manifests`) — descartada para evitar overhead de sincronização entre dois repos.

### 11. Arquitetura limpa de manifestos — Helm único (revisão 2026-09-08)
- **Problema:** havia duplicação entre `k8s/base/` (Kustomize) e `k8s/helm/`, além de YAMLs achatados e paths errados no CI (`todolist-app/`, `k8s/base/app.yaml`).
- **Decisão:** `k8s/base/` **removido**. `k8s/helm/todolist-app/` é a **fonte única**, com templates organizados por função (namespace, postgresql, deployment, service, ingress, hpa, pdb, configmap, secret, serviceaccount, rbac, pull-secret, cronjob). Os namespaces (app + db) também são declarados no chart — GitOps puro (repo é a fonte da verdade; Terraform apenas provisiona cluster + ArgoCD + credenciais).
- **CI unificado:** 3 workflows (`build.yaml`, `build-push.yml`, `ci.yaml`) reduzidos a **1** — `.github/workflows/ci.yaml` (test → build → scan → deploy GitOps mono-repo). O deploy promove a imagem editando `image.tag` no `values.yaml` do chart; o ArgoCD (selfHeal) re-sincroniza.
- **Evidência de funcionamento:** `helm template` renderiza 17 recursos (antes: base 17 = duplicado); `helm lint` 0 falhas; `helm unittest` 19/19 passando.

### 10. Plugin mermaid para renderização
Criado `dsh-plugin-mermaid/` — plugin que registra `mermaidRenderer` no cordis do DSH, com CLI `dsh-render-md` (PNG/SVG) e `dsh-md-preview` (servidor local com Mermaid.js CDN).
O README é o índice. `docs/DECISOES.md` explica o "porquê". `docs/DESAFIOS.md` registra obstáculos.
