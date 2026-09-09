# Registro de Decisões

## Escopo do projeto

Este documento registra as escolhas técnicas, os desafios encontrados e o que foi descartado durante a implementação da plataforma Kubernetes local com GitOps.

---

## Ambiente: Kind (local) em vez de cloud (EKS/GKE)

**Decisão:** cluster Kubernetes local com Kind.

**Justificativa:**
- Limitações de billing em cloud impedem o uso de EKS/GKE neste momento.
- Kind é recomendado pela documentação oficial do Kubernetes para ambientes locais ([kind.sigs.k8s.io](https://kind.sigs.k8s.io/)).
- Ambiente único (local), sem necessidade de múltiplos clusters (dev/staging/prod).
- Pipeline simplificada para um único ambiente.
- O conceito GitOps é mantido: o Git continua sendo a fonte de verdade (Helm chart no repositório). A infraestrutura é provisionada via CLI local (`make create` / `terraform apply`). Em ambiente cloud, seria automatizada via Terraform Cloud ou GitHub Actions com provider cloud.

---

## Pipeline simplificada (CI)

**Decisão:** pipeline única (`.github/workflows/ci.yaml`) em 4 jobs — `test` → `build` → `scan` → `deploy`.

**Justificativa:**
- Ambiente único (local), sem necessidade de pipelines separadas por ambiente.
- O deploy é via ArgoCD (GitOps): o job `deploy` atualiza o `values.yaml` com a nova imagem e ArgoCD sincroniza automaticamente.
- Em ambiente cloud com múltiplos clusters, seria necessário Terraform Cloud para infra, GitHub Actions para build/scan e ArgoCD multi-cluster para deploy.

---

## Desafios encontrados

### 1. Provider `tehcyx/kind` (v0.11.0) crashava ao provisionar

- **Problema:** `terraform apply` quebrava com `Error: The terraform-provider-kind plugin crashed!` ao criar o cluster.
- **Correção:** substituir o resource `kind_cluster` do provider de terceiros por `null_resource` + `local-exec` rodando `kind create cluster --config kind-config.yaml`. O cluster continua sendo provisionado por código — mudou apenas como o Terraform executa o `kind`.
- **Alternativa descartada:** manter o provider antigo (instável) ou migrar para cloud (indisponível).

### 2. Helm 3.19: `--set controller.nodeSelector...` quebrava o ingress-nginx

- **Problema:** `helm upgrade --install ingress-nginx` falhava com `json: cannot unmarshal object` — o `--set` com chave pontuada era interpretado como string.
- **Correção:** usar `--set-json 'controller.nodeSelector={...}'` (sintaxe explícita de JSON).

### 3. Cache do Helm bloqueado pelo sandbox de arquivos

- **Problema:** Helm não conseguia gravar em `~/.cache/helm/repository` (`permission denied`).
- **Correção:** direcionar o cache para `/tmp` via `HELM_CACHE_HOME`/`HELM_CONFIG_HOME`/`HELM_DATA_HOME` (Helm 3.16+ usa XDG).

### 4. Race condition no cold-start (CrashLoopBackOff)

- **Problema:** o primeiro pod da app entrou em `CrashLoopBackOff` até o Postgres estar pronto.
- **Observação:** estabilizou sozinho (app e db `Running`). Comportamento esperado de cold-start, mitigado por probes/PDB.

---

## Ferramentas de apoio ao desenvolvimento

**Ferramentas:** DeepSeek Harness (DSH) como ambiente de agente e Omniroute como gateway de IA (tokens gratuitos / modelos free).

**Por que:** o projeto libera o uso de IA (PDF seção 3: "Uso de IA: Liberado e sem estigma"). Omniroute permite rotear chamadas para modelos gratuitos, eliminando custo de tokens. Todo o código gerado com apoio de IA passa pelos mesmos critérios dos requisitos — a IA é ferramenta de apoio, não decisora.

---

## Melhorias futuras

### ArgoCD Image Updater

**O que é:** componente oficial do ArgoCD que vigia um registry (ex.: GHCR) e atualiza automaticamente a tag da imagem no `values.yaml` do Helm — sem precisar de script de CI.

**Por que não implementamos agora:** o escopo é local (Kind), single-environment, e o `promote-image.py` já resolve o mesmo problema com zero peças extras no cluster. O Image Updater adiciona um deployment no `argocd`, mais um secret de registry, mais um secret de git (para write-back), e mais uma camada de observabilidade — complexidade desnecessária no Kind para um desafio de 7 dias.

**O que muda (se implementado):**
- CI passa a ser só `test` + `build` (sem job `deploy`).
- O `promote-image.py` é removido.
- ArgoCD Application ganha annotations (`argocd-image-updater.argocd.io/image-list`, `write-back-method`, `helm.image-name`, etc.).
- O updater commita automaticamente a nova tag no repo (write-back git); ArgoCD re-sincroniza.

**Referências:**
- ArgoCD Image Updater Docs: https://argocd-image-updater.readthedocs.io/
- ArgoCD Image Updater Helm Chart (argo-helm): https://github.com/argoproj/argo-helm/tree/master/charts/argocd-image-updater

### CI com paths filter

**O que é:** restringir o workflow do CI para rodar `build`/`deploy` só quando muda `app/**` ou `k8s/**` (evita builds desnecessários por mudanças em README ou docs).

---

## Referências
- Kubernetes Docs — Local Clusters: [https://kind.sigs.k8s.io/](https://kind.sigs.k8s.io/)
- ArgoCD Docs: [https://argo-cd.readthedocs.io/](https://argo-cd.readthedocs.io/)
- Helm Docs: [https://helm.sh/docs/](https://helm.sh/docs/)
- DeepSeek Harness (DSH): [https://github.com/deepseek-ai/dsh](https://github.com/deepseek-ai/dsh)
- Omniroute (gateway de IA): [https://github.com/diegosouzapw/OmniRoute](https://github.com/diegosouzapw/OmniRoute)
