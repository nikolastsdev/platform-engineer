# Registro de Decisões — Platform Engineer Challenge

## Escopo
- Foco exclusivo nos requisitos R1–R5 (PDF seção 6–7): provisionamento por código, deploy automatizado, acesso externo, escalabilidade/resiliência, documentação.
- Não expandido: nenhuma nova ferramenta além do que já existia (terraform, kind, helm, argocd). Não foram adicionados CI extra, observabilidade, nem alteração de código da app (PDF seção 5: não obrigatório).
- Referência: "Ir além deles é opcional, e não ir também é uma decisão válida. Nossa sugestão é priorizar os requisitos antes de ampliar o escopo." (PDF seção 7).

---

## Ambiente: Kind (local) em vez de cloud (EKS/GKE)

**Decisão:** Rodar o cluster Kubernetes localmente com Kind.

**Argumento:**
- Não há disponibilidade de utilizar serviço de cloud devido a burocracias de billing / cadastramento de conta de faturamento.
- Por isso, optei por construir um laboratório local de Kubernetes, usando a ferramenta Kind — recomendada pela própria documentação oficial do Kubernetes para rodar ambientes locais ([https://kind.sigs.k8s.io/](https://kind.sigs.k8s.io/)).
- Não estamos utilizando múltiplos ambientes (dev/staging/prod); o escopo é apenas local.
- A pipeline foi simplificada para focar nos requisitos (R1–R5), sem adicionar camadas de complexidade desnecessárias.
- O conceito GitOps é mantido: o Git continua sendo a fonte de verdade (Helm chart e manifests no repositório). A infraestrutura, entretanto, é provisionada via CLI local (`make create` / `terraform apply`), já que o ambiente é local. Se fosse cloud, a infraestrutura seria provisionada por uma pipeline automatizada (ex.: Terraform Cloud, GitHub Actions com provider AWS). Como é local, a escolha foi CLI para manter a simplicidade alinhada ao escopo.

---

## Pipeline simplificada (CI)

**Decisão:** Pipeline única (`.github/workflows/ci.yaml`) em 4 jobs — `test` → `build` → `scan` → `deploy`.

**Argumento:**
- Não havia necessidade de pipelines separadas (build, scan, deploy) dado o escopo de um único ambiente local.
- A abordagem GitOps é mantida: o deploy é feito via ArgoCD a partir do Helm chart no repo (mono-repo). O job `deploy` do CI atualiza o `values.yaml` do Helm com a nova imagem, e ArgoCD sincroniza automaticamente.
- Se fosse um ambiente de cloud com múltiplos clusters, a pipeline seria mais complexa (Terraform Cloud para infra, GitHub Actions para build/scan, ArgoCD multi-cluster para deploy). A simplificada aqui reflete o ambiente local (único).

---

## Desafios encontrados (relato — PDF seção 8, item 3)

### 1. Provider `tehcyx/kind` (v0.11.0) crashava ao provisionar
- **Problema:** `terraform apply` quebrava com `Error: The terraform-provider-kind plugin crashed!` ao criar o cluster (config v0.11.0 desatualizada; `extra_port_mappings` vazio no node control-plane era gatilho de panic).
- **Correção escolhida:** substituir o resource `kind_cluster` do provider de terceiros por `null_resource` + `local-exec` rodando `kind create cluster --config kind-config.yaml` (CLI oficial, idempotente, 100% por código). O cluster continua sendo provisionado por código (R1 intacto) — mudou apenas **como** o Terraform executa o `kind`.
- **O que descartei:** manter o provider antigo (instável) e usar kind v1 em cloud (não há cloud disponível — ver decisão acima).

### 2. Helm 3.19: `--set controller.nodeSelector...` quebrava o ingress-nginx
- **Problema:** `helm upgrade --install ingress-nginx` falhava com `json: cannot unmarshal object into Go struct field PodSpec.spec.template.spec.nodeSelector of type string` — o `--set` com chave pontuada (`node-role.kubernetes.io/control-plane`) era interpretado como string no Helm 3.19.
- **Correção escolhida:** usar `--set-json 'controller.nodeSelector={...}'` (sintaxe explícita de JSON), que o Helm 3.19 trata corretamente.

### 3. Cache do Helm bloqueado pelo sandbox de arquivos local
- **Problema:** ao rodar localmente, o Helm não conseguia gravar em `~/.cache/helm/repository` (`permission denied`), abortando `helm repo add/upgrade`.
- **Correção escolhida:** na execução local, direcionar o cache para `/tmp` via `HELM_CACHE_HOME`/`HELM_CONFIG_HOME`/`HELM_DATA_HOME` (Helm 3.16+ usa XDG). Nenhuma mudança de arquitetura — é configuração de ambiente de execução.

### 4. Transientes de readiness da app (CrashLoopBackOff inicial)
- **Problema:** o primeiro pod da app entrou em `CrashLoopBackOff` por segundos até o Postgres estar pronto (race de bootstrap).
- **Observação:** estabilizou sozinho (app e db `Running`); não exigiu mudança de código. Ficou registrado como comportamento esperado de cold-start, mitigado por probes/PDB.

---

## Ferramentas de apoio ao desenvolvimento (e por que)

**Decisão:** usamos **DeepSeek Harness (DSH)** como ambiente de agente de IA e **Omniroute** como gateway de IA, com o objetivo de obter tokens gratuitos e usar modelos de IA *free* durante o desenvolvimento destas decisões e da implementação.

**Argumento:**
- O desafio libera o uso de IA sem estigma (PDF seção 3: "Uso de IA: Liberado e sem estigma. O que esperamos é que você consiga explicar as decisões do código").
- Omniroute como gateway permite rotear chamadas para modelos gratuitos, eliminando custo de tokens no desenvolvimento.
- O DeepSeek Harness foi o ambiente (orquestração de agente/CLI) usado para executar e documentar o fluxo.
- Todo o código gerado/validado com apoio de IA passa pelos mesmos critérios dos requisitos (R1–R5); a IA é ferramenta de apoio, não decisora — as escolhas técnicas estão registradas neste documento.

---

## Melhorias futuras (com mais tempo de projeto)

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
