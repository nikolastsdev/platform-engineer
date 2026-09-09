# Roteiro de Apresentação — Platform Engineer (Todolist)

Guia completo para apresentar o projeto e responder perguntas da banca. Este roteiro tem três níveis: **pitch de 60s**, **narrativa de 3 min** e **explicação profunda por requisito**. No final há glossário de termos, Q&A com respostas prontas e roteiro de demonstração.

---

## 1. Pitch de 60 segundos

> "Construí uma **plataforma Kubernetes local** com deploy 100% automatizado via **GitOps**. O cluster Kind (4 nodes) é **provisionado por código com Terraform** — `make create` sobe tudo: cluster, ingress, métricas e ArgoCD. A aplicação (Flask + PostgreSQL) é **deployed pelo ArgoCD** a partir do Helm chart versionado no repositório: quando o CI publica uma nova imagem no GitHub Container Registry, ele **promove a tag no chart e o ArgoCD sincroniza sozinho**. A app é **acessível pelo navegador** em `http://localhost` via Ingress NGINX. Para **escalabilidade e resiliência**, o deployment tem HPA (2→10 pods por CPU/memória), PodDisruptionBudget, probes de saúde no `/healthz` e initContainer que espera o banco. Tudo documentado: decisões técnicas, desafios e evidências reais de execução no repositório."

**Duração:** ~55s. Se cortar algo, remova a frase do CI (promote) ou o detalhe das métricas.

---

## 2. Narrativa de 3 minutos

1. **Problema/objetivo:** entregar um ambiente Kubernetes onde infraestrutura e aplicação nascem de código e se atualizam sozinhas — repetível e documentado.
2. **Provisionamento (IaC):** `make create` executa `terraform init + apply`. O Terraform cria o cluster Kind com `kind create cluster --config kind-config.yaml` (via `null_resource` + `local-exec`) e instala por Helm: **ingress-nginx 4.11.2** (portas 80/443), **metrics-server 3.12.1** (base do HPA) e **ArgoCD 7.4.0** (NodePort 30080 → host 8080). Tudo idempotente, sem passos manuais.
3. **Deploy GitOps (R2):** o Terraform também registra a **ArgoCD Application** apontando para o repo (`k8s/helm/todolist-app`, branch `HEAD`). O ArgoCD observa o repositório e aplica os manifests. **Git é a fonte da verdade** — ninguém aplica `kubectl apply` na app manualmente.
4. **CI/CD:** em todo push para `main`, o GitHub Actions: roda testes da app (Python + Postgres), **builda e publica a imagem no GHCR** (`ghcr.io/nikolastsdev/platform-engineer/todolist:<sha>`), e um script (`promote-image.py`) **atualiza a tag da imagem no `values.yaml`** do chart. O ArgoCD detecta a mudança no repo e sincroniza — deploy automático de nova versão.
5. **Acesso externo (R3):** o Ingress NGINX expõe a app em `http://localhost/` (Service NodePort interno 5000). ArgoCD em `https://localhost:8080`.
6. **Escalabilidade/resiliência (R4):** HPA entre 2 e 10 réplicas (CPU 70% / memória 80%), PDB com `minAvailable: 1`, **liveness/readiness/startup probes** no `/healthz` (que valida o Postgres com `SELECT 1`), initContainer `wait-for-db`.
7. **Documentação (R5):** README com todo o caminho de execução, `docs/decisoes/` com registro de decisões e desafios, `docs/evidencias/` com logs reais, e este roteiro.

---

## 3. Explicação profunda — por requisito

### R1 — Provisionamento por código (IaC)

**Termos:** IaC, Terraform, `null_resource`, `local-exec`, provider, state, idempotência, Kind, kubeconfig, extraPortMappings, DaemonSet, hostNetwork, NodePort.

**O que acontece:** `make create` → `terraform init` → `terraform apply`. O plano cria **7 resources** (evidência no `docs/evidencias/log-make-create.txt`):

| # | Resource | O que executa |
|---|----------|---------------|
| 1 | `create_kind_cluster` | `kind create cluster --config kind-config.yaml` → 4 nodes (1 control-plane + 3 workers), Kubernetes v1.30.0 |
| 2 | `install_ingress` | Helm: ingress-nginx 4.11.2 (control-plane, hostNetwork, portas 80/443) |
| 3 | `install_metrics_server` | Helm: metrics-server 3.12.1 (`--kubelet-insecure-tls`, exigência local do Kind) |
| 4 | `install_argocd` | Helm: ArgoCD 7.4.0 (NodePort https 30080) |
| 5 | `create_namespaces` | Namespaces `todolist` e `todolist-db`, `imagePullSecret ghcr-pull` (PAT via `gh auth token`, **nunca vai para o Git**) |
| 6 | `argocd_repo_credentials` | Secret do ArgoCD com a URL/credencial do repositório GitOps |
| 7 | `argocd_app_todolist` | Manifests: Ingress do ArgoCD (`argocd.localhost`) + **ArgoCD Application** `todolist-app` |

**Por que `null_resource` + `local-exec` em vez de um provider de Kind?** O provider `tehcyx/kind` (v0.11.0) crashava no `apply` (bug documentado em `docs/decisoes/`). O workaround usa a CLI oficial do Kind dentro do Terraform — o cluster **continua sendo provisionado por código**, só muda o mecanismo.

**Por que Kind e não cloud?** Sem conta de billing em cloud no momento; Kind é a ferramenta recomendada pela documentação oficial do Kubernetes para ambiente local. O fluxo (Terraform → GitOps → Ingress) é o mesmo de um cluster EKS/GKE real.

**Portas expostas no host** (via `extraPortMappings` no control-plane): 80/443 (ingress da app) e 30080→8080 (ArgoCD). Sem port-forward.

**Se perguntarem "cadê o state remoto?"** — backend local (`terraform/terraform.tfstate`), suficiente para um ambiente local de laboratório. Em cloud usaria backend remoto (S3/GCS) com lock.

---

### R2 — Deploy automatizado de nova versão (GitOps)

**Termos:** GitOps, ArgoCD, Application, source/destination, targetRevision, sync, selfHeal, prune, mono-repo, promote, GHCR, imagePullSecret, polling vs webhook.

**Fluxo completo de uma nova versão:**

```
push para main
  → job test   (Python import + Postgres service)
  → job build  (docker build → GHCR: ghcr.io/.../todolist:<sha> e :latest)
  → job deploy (scripts/promote-image.py atualiza image.tag no values.yaml
                → commit "chore: promove imagem todolist para <sha> [skip ci]")
  → ArgoCD detecta mudança no repositório (targetRevision: HEAD)
  → ArgoCD sincroniza o Helm chart → Deployment atualiza a imagem
```

**Transparência importante:** o ArgoCD **observa o repo por polling** (default ~3 min), não há webhook configurado — aceitável para laboratório; em produção configuraria webhook/repository credentials + Image Updater (documentado como melhoria futura).

**O `promote-image.py`** atualiza **somente** a tag da imagem da app (linha `tag:` seguida de `pullPolicy:`), para não casar com a tag do Postgres (`postgresql.image.tag`).

**Por que imagem por SHA e não só `latest`?** O `values.yaml` aponta para o SHA do commit — rastreável e imutável. `latest` é publicada para conveniência, mas o GitOps usa o SHA.

**ArgoCD Application (manifest no `argocd.tf`):**
- `source.repoURL` = repo Git; `path` = `k8s/helm/todolist-app`; `targetRevision` = `HEAD`
- `destination.namespace` = `todolist`
- `syncPolicy.automated`: `prune: true` (remove recursos que sumiram do Git) + `selfHeal: true` (reverte qualquer drift manual) — **Git é a única fonte da verdade**.

**Saídas esperadas:** `SYNC STATUS: Synced` e `HEALTH STATUS: Healthy` (evidência em `resumo-kubectl.txt`).

---

### R3 — Acesso externo (navegador)

**Termos:** Ingress, IngressClass, ingress-nginx controller, Service (NodePort/ClusterIP), rewrite-target, host virtual, TLS passthrough, redirect.

**Como o tráfego chega na app:**

```
Navegador → localhost:80 (host port mapping do Kind)
          → ingress-nginx controller (DaemonSet, hostNetwork no control-plane)
          → Ingress "todolist-app" (host: localhost, path /, rewrite-target: /)
          → Service "todolist-app" (NodePort 30000, porta 5000)
          → Pods do Deployment (gunicorn na porta 5000)
```

- A app responde `HTTP 302 → /login` em `/` e `200` em `/login` (evidência `curl-acesso.txt`).
- **ArgoCD:** `https://localhost:8080` (NodePort 30080) — senha via `make argocd-password` (`argocd-initial-admin-secret`, base64). Existe também um Ingress para `argocd.localhost` com `ssl-passthrough` (o server do ArgoCD fala TLS direto).
- **Service da app:** tipo NodePort 30000, mas o acesso externo real é pelo Ingress (porta 80). O NodePort existe como alternativa interna.

**Se perguntarem "qual a diferença Ingress x Service?"** — Service é o ponto de entrada dentro do cluster (IP/porta estáveis, load balance entre pods). Ingress é o roteador de borda (HTTP host/path, TLS, rewrite) que encaminha para o Service.

---

### R4 — Escalabilidade e resiliência

**Termos:** HPA, autoscaling/v2, utilização de recurso, stabilization window, PDB, disruptions, probes (liveness/readiness/startup), initContainer, pg_isready, grace period, mínimo de réplicas.

**O que existe no chart (`values.yaml` + templates):**

| Mecanismo | Configuração | Papel |
|-----------|-------------|-------|
| **HPA** (`hpa.yaml`) | min 2 / max 10; CPU 70%, memória 80% (`autoscaling/v2`) | Escala automática por utilização de recurso |
| **Behavior do HPA** | scaleUp: +100% ou +4 pods a cada 15s (`selectPolicy: Max`); scaleDown: janela de estabilização 300s, máx 10%/60s | Sobe rápido, desce devagar (evita flapping) |
| **PDB** (`pdb.yaml`) | `minAvailable: 1` | Garante que nunca fique sem pod durante drenagem/manutenção (voluntary disruptions) |
| **Probes** (`deployment.yaml`) | liveness/readiness/startup → `GET /healthz` | Readiness: só manda tráfego quando saudável; liveness: reinicia pod travado; startup: segura o início até a app subir |
| **`/healthz` da app** (`app.py`) | `SELECT 1` no Postgres → `200 ok` / `503` | Health check com semântica de dependência (DB) |
| **initContainer `wait-for-db`** | `pg_isready` em loop | Evita corrida de bootstrap app×banco |
| **Postgres** (`postgresql.yaml`) | Deployment 1 réplica, estratégia `Recreate`, probes `pg_isready` | Banco dedicado no namespace `todolist-db` |

**Detalhe de engenharia:** com HPA habilitado, o Deployment **não define `replicas`** (o HPA controla); o `replicaCount: 3` do `values.yaml` só vale se `autoscaling.enabled: false`.

**Por que startupProbe além de readiness?** A app pode demorar no cold-start (Postgres ainda subindo). O startupProbe (failureThreshold 30 × 5s ≈ 2,5 min) "segura" as outras probes até a app ficar pronta — é o que absorve aquele CrashLoopBackOff inicial documentado.

**HPA depende de quê?** Do metrics-server (instalado pelo Terraform). Sem métricas, o HPA não tem dados — por isso o componente existe na stack.

---

### R5 — Documentação, decisões e evidências

- **README.md** — visão geral, requisitos R1–R5, pré-requisitos, execução, estrutura do repo, CI/CD, acessos, escalabilidade/resiliência, decisões, evidências.
- **docs/decisoes/escopo-decisoes.md** — decisões (Kind local, pipeline única), desafios encontrados (provider kind crash, Helm 3.19 `--set-json`, cache Helm, cold-start), ferramentas de apoio, melhorias futuras (ArgoCD Image Updater, paths filter).
- **docs/evidencias/** — artefatos reais: log do `make create`, resumo `kubectl` (nodes/pods/ingress/HPA/PDB), `curl` de acesso (302→200), página de login renderizada, roteiro de prints para o relatório.
- **docs/arquitetura/** — diagrama interativo publicado no GitHub Pages (`pages.yaml` → https://nikolastsdev.github.io/platform-engineer/arquitetura.html).
- **Testes do chart** (`k8s/helm/todolist-app/tests/deployment_test.yaml`) — helm-unittest com snapshot: probes, replicas com/sem HPA, Service NodePort/ClusterIP, Ingress on/off, Secret, HPA, PDB, ServiceAccount, RBAC, CronJob on/off, initContainer.

---

## 4. Mapa de arquivos (referência rápida)

| Arquivo | Para que serve | Requisito |
|---------|----------------|-----------|
| `terraform/main.tf` | 7 resources que provisionam cluster + dependências | R1 |
| `terraform/kind-config.yaml` | Config declarativa do cluster (nodes + portas) | R1 |
| `terraform/argocd.tf` | Ingress ArgoCD + Application GitOps | R2 |
| `terraform/variables.tf` / `outputs.tf` / `providers.tf` | Parâmetros, outputs e provider `null` | R1/R5 |
| `Makefile` | `create`, `destroy`, `reset`, `clean`, `argocd-password` | R1 |
| `.github/workflows/ci.yaml` | test → build (GHCR) → deploy (promote) | R2 |
| `.github/workflows/pages.yaml` | Publica diagrama no GitHub Pages | R5 |
| `scripts/promote-image.py` | Promove a tag SHA no `values.yaml` | R2 |
| `k8s/helm/todolist-app/` | Chart: deployment, service, ingress, hpa, pdb, postgresql, cronjob, rbac, secrets | R2/R3/R4 |
| `app/todolist/app.py` | Flask app: login, CRUD, `/pods`, `/cleanup/status`, `/healthz` | R3/R4 |
| `app/todolist/Dockerfile` | Imagem Python 3.13-slim, gunicorn, HEALTHCHECK `/healthz` | R2/R4 |
| `docs/` | arquitetura + decisões + evidências | R5 |

---

## 5. Glossário — termos na ponta da língua

### Infraestrutura como código
- **IaC (Infrastructure as Code):** infraestrutura descrita em arquivos versionados, aplicada de forma repetível; aqui o Terraform.
- **Terraform:** ferramenta declarativa da HashiCorp; você descreve o estado desejado e ele aplica.
- **`null_resource` + `local-exec`:** resource "vazio" do Terraform que dispara comandos locais no `apply` — mecanismo usado para rodar `kind`/`helm`/`kubectl` por código.
- **Provider:** plugin que o Terraform usa para falar com um sistema (aqui só o `null`).
- **State (tfstate):** arquivo que registra o que o Terraform criou, usado para plan/destroy.
- **Idempotência:** rodar o mesmo comando N vezes produz o mesmo resultado (sem efeitos colaterais duplicados).
- **Apply/Destroy/Plan:** aplicar mudanças, destruir recursos, e simular as mudanças antes de aplicar.

### Kubernetes
- **Kind:** Kubernetes in Docker — roda o `kubelet` e o `kube-apiserver` dentro de containers Docker; ambientes locais de teste.
- **Node control-plane / worker:** nó que roda o plano de controle (API server, scheduler) vs nó que roda os workloads (pods).
- **Kubeconfig:** arquivo de configuração com credenciais/clusters/contextos do `kubectl`.
- **Namespace:** divisão lógica do cluster para isolar recursos (aqui: `todolist`, `todolist-db`, `argocd`, `ingress-nginx`).
- **Pod:** menor unidade executável — um ou mais containers.
- **Deployment:** controlador que garante o número desejado de réplicas e faz rollout de novas versões.
- **ReplicaSet:** mantém o número de réplicas do Deployment (gerenciado por ele, não se mexe direto).
- **Service:** IP/porta estáveis que distribuem tráfego para os pods (aqui: `ClusterIP` para o Postgres, `NodePort` para a app).
- **Ingress / IngressClass:** roteador HTTP de borda; o Ingress declara host/path/backend; o controller (ingress-nginx) implementa.
- **NodePort:** expõe o Service numa porta alta de todos os nodes (aqui 30000 na app, 30080 no ArgoCD).
- **ConfigMap / Secret:** configuração não-sensível vs sensível injetada no pod (via `envFrom`/`secretKeyRef`).
- **ServiceAccount:** identidade do pod dentro do cluster (o app usa para falar com a API do K8s).
- **RBAC / Role / RoleBinding:** controle de acesso; quem pode fazer o quê num namespace.
- **Menor privilégio:** conceder só as permissões mínimas necessárias (app: `get/list/watch` em pods e cronjobs).
- **Downward API / ServiceAccount token:** arquivos montados em `/var/run/secrets/kubernetes.io/serviceaccount/` usados pelo app para autenticar na API.
- **extraPortMappings:** mapeamento de portas do Kind para o host (80/443/30080→8080).

### GitOps e deploy
- **GitOps:** modelo onde o Git é a fonte da verdade operacional; agentes aplicam o estado descrito no repo.
- **ArgoCD:** operador GitOps que observa o repo e sincroniza os manifests no cluster.
- **Application (ArgoCD):** recurso que declara source (repo+path+branch) e destination (cluster+namespace).
- **Sync / Synced / Healthy:** sincronização do estado desejado; status do recurso no cluster.
- **SelfHeal:** ArgoCD reverte mudanças manuais no cluster (drift) de volta ao que o Git diz.
- **Prune:** remove recursos que deixaram de existir no Git.
- **Drift:** divergência entre o cluster e o Git.
- **Polling vs Webhook:** ArgoCD verifica o repo a cada intervalo (polling) ou é notificado por evento (webhook).
- **Mono-repo:** chart da app e código da app no mesmo repositório (simplifica o GitOps aqui).
- **Promote (imagem):** atualizar a referência da imagem (tag) no manifesto — o que o `promote-image.py` faz.
- **GHCR (GitHub Container Registry):** registry de containers do GitHub onde a imagem é publicada.
- **imagePullSecret:** Secret do tipo `kubernetes.io/dockerconfigjson` usado pelo kubelet para autenticar no registry.

### CI/CD
- **CI (Continuous Integration) / CD (Continuous Delivery/Deployment):** automatizar testes/build e entregar/deployar versões.
- **GitHub Actions:** CI/CD do GitHub; workflows YAML com jobs e steps.
- **Job / Step / Runner:** unidade de trabalho / passo / máquina que executa.
- **Service (GitHub Actions):** container auxiliar do job (aqui Postgres para os testes).
- **Gunicorn:** servidor WSGI de produção do Python (2 workers × 2 threads).
- **HEALTHCHECK (Docker):** comando do Dockerfile que valida a saúde do container (`curl /healthz`).
- **Trivy:** scanner de vulnerabilidades de imagem; config presente (`.trivy.yml`) mas o job de scan foi despriorizado no tempo do desafio.
- **SHA (commit):** hash imutável que identifica a versão exata; usado como tag da imagem.

### Escalabilidade e resiliência
- **HPA (HorizontalPodAutoscaler):** ajusta réplicas pela utilização de métricas (aqui CPU 70% / memória 80%, min 2 / max 10).
- **`autoscaling/v2`:** versão atual da API do HPA com múltiplas métricas por alvo.
- **Stabilization window:** período para evitar oscilação (flapping) ao escalar para baixo (300s).
- **PDB (PodDisruptionBudget):** limita quantos pods podem ser indisponibilizados por ações voluntárias (dreno, manutenção) — aqui `minAvailable: 1`.
- **Voluntary vs Involuntary disruptions:** manutenção programada vs falha de nó/máquina; PDB só protege contra voluntárias.
- **Liveness probe:** indica se o container está vivo; falha → reinício.
- **Readiness probe:** indica se o pod pode receber tráfego; falha → removido do Service.
- **Startup probe:** paralisa as demais probes durante a inicialização lenta.
- **InitContainer:** container que roda antes dos principais (aqui `wait-for-db` com `pg_isready`).
- **`pg_isready`:** utilitário do Postgres que testa a conexão com o banco.
- **Race condition (cold-start):** corrida entre a app subir e o banco ficar pronto — o problema do CrashLoopBackOff inicial.

### Observabilidade (leve)
- **Metrics Server:** agrega métricas de CPU/memória dos kubelets; alimenta o HPA.
- **Probe endpoint / health check:** endpoint HTTP que reporta saúde; o `/healthz` da app faz `SELECT 1` no DB.

---

## 6. Q&A — perguntas prováveis e respostas prontas

### Sobre a stack
**"Por que Kind e não um cluster em cloud (EKS/GKE/kind mesmo)?"**
> Sem disponibilidade de billing de cloud no momento. Kind é a recomendação oficial do Kubernetes para laboratório local e reproduz o mesmo fluxo (Terraform → GitOps → Ingress). As decisões de arquitetura não mudam ao migrar para cloud — só o destino do Terraform e o acesso.

**"Usar `null_resource` + `local-exec` é considerado 'provisionar por código'?"**
> Sim: o que define IaC é a infraestrutura nascer de um comando repetível e versionada. Aqui o cluster, os charts e os manifests são aplicados pelo Terraform com um único comando (`make create`). O `local-exec` apenas executa as ferramentas oficiais (kind CLI, helm, kubectl) de forma declarada e ordenada. A alternativa (provider `tehcyx/kind`) crashava — o bug está documentado em `docs/decisoes/`.

**"Por que Terraform em vez de só shell scripts?"**
> Orquestração, ordem, estado e `destroy` automático. O `terraform destroy` + Makefile limpa cluster, containers e rede — repetível e sem passos manuais. O shell puro não teria estado nem plano.

### Sobre GitOps e deploy
**"Como uma nova versão chega ao cluster?"**
> Push → CI testa e publica a imagem no GHCR com o SHA; o job `deploy` promove a tag no `values.yaml` (via `promote-image.py`) e commita; o ArgoCD observa o repo (`targetRevision: HEAD`) e sincroniza o chart, fazendo o rollout. Nenhum `kubectl apply` manual da app.

**"Por que o commit do deploy é `[skip ci]`?"**
> Para o push do próprio job `deploy` não re-disparar a pipeline infinita (build do commit do próprio CI). É um padrão comum em GitOps por commit.

**"E se alguém alterar o cluster na mão?"**
> `selfHeal: true` reverte o drift de volta ao Git — o cluster converge para o estado descrito no repositório.

**"O ArgoCD usa webhook?"**
> Não neste ambiente — polling (default ~3 min). Sem gate de rede externo no laboratório, polling é suficiente. Em produção eu configuraria o webhook do GitHub no ArgoCD (ou ArgoCD Image Updater, documentado como melhoria futura).

**"Por que imagem por SHA e não `latest`?"**
> SHA é imutável e rastreável: `values.yaml` aponta exatamente para a versão testada daquele commit. `latest` é publicada para conveniência, mas o GitOps referencia o SHA.

### Sobre segurança
**"Os secrets estão no `values.yaml` (senha do Postgres, admin). Isso é seguro?"**
> São valores de desenvolvimento/documentação. O chart monta um Secret do Kubernetes (não expõe em env vars). A nota no `values.yaml` e nas decisões indica que produção usaria SealedSecrets, External Secrets Operator ou Vault. O que **nunca** entra no Git é o PAT do GHCR — criado em tempo de execução pelo Terraform via `gh auth token`.

**"Para que serve o ServiceAccount da app?"**
> A app consulta a API do Kubernetes (páginas `/pods` e `/cleanup/status`). O ServiceAccount dá identidade ao pod e o RBAC limita a permissão ao mínimo: `get/list/watch` em pods e cronjobs/jobs do próprio namespace. Nada de cluster-wide.

**"E o `patch` do CronJob (suspender/retomar)?"**
> Ponto de atenção honesto: o Role lista `get/list/watch` para cronjobs, mas o `PATCH` de suspend exige o verbo `patch`/`update` — o botão pode retornar 403 na prática. As páginas de leitura (`/pods`, histórico) funcionam. Correção: adicionar `update`/`patch` ao Role (1 linha), se quisermos o toggle funcional.

**"O Postgres usa `emptyDir`. E se o pod reiniciar?"**
> Os dados são voláteis no laboratório — aceitável porque é ambiente de demonstração. Em produção, um PVC/PV (ou managed database) garantiria persistência. É uma decisão consciente do escopo local, não um esquecimento.

**"E a imagem? Passou por scan de vulnerabilidades?"**
> O `ci.yaml` teve uma etapa Trivy que foi despriorizada no tempo do desafio. Ficou a configuração (`.trivy.yml`, falha apenas por CVEs corrigíveis) e o Dockerfile já fixa versões com CVEs (msgpack, setuptools, psycopg2, requests). Reativar o scan é trivial e está no radar das melhorias.

### Sobre escalabilidade
**"O HPA escala por quê?"**
> CPU e memória (utilização média sobre as réplicas): CPU 70%, memória 80%, entre 2 e 10 pods. Depende do metrics-server (instalado por código). O HPA tem behavior: sobe rápido (+100% ou +4 pods/15s) e desce devagar (estabilização de 300s) para não oscilar.

**"PDB com 2 pods mínimos e minAvailable 1 — não conflita?"**
> PDB garante 1 pod disponível durante drenagem/manutenção (disruptions voluntárias). Com `Recreate` no Postgres e probes na app, o rollout mantém disponibilidade. Não conflita: são proteções complementares.

**"O que acontece se a app travar (hang)?"**
> A readiness probe tira o pod do Service (sem tráfego), a liveness reinicia o container, e o HPA/PDB seguram réplicas disponíveis. O cold-start é coberto pelo startupProbe + initContainer.

### Sobre o desafio em si
**"Qual foi o maior desafio técnico?"**
> O provider de Kind crashava no Terraform — passei a rodar a CLI oficial via `null_resource` mantendo o provisionamento por código. Depois, o Helm 3.19 quebrava com `--set` de nodeSelector (corrigido com `--set-json`) e o cold-start app×banco (initContainer + startupProbe).

**"O que você faria diferente com mais tempo?"**
> Persistência real do Postgres (PVC), ArgoCD Image Updater (removeria o `promote-image.py`), CI com paths filter, scan de imagem (Trivy) reativado e webhook do ArgoCD.

---

## 7. Demonstração ao vivo (roteiro de comandos)

**Pré-requisito:** ambiente no ar (`make create` já executado). Combine com o avaliador se vai executar do zero.

```bash
# 1. Estado do cluster (R1)
kubectl get nodes -o wide                          # 4 nodes Ready, v1.30.0
kubectl get pods -A                                # argocd, ingress-nginx, metrics-server, todolist, todolist-db

# 2. GitOps (R2)
kubectl -n argocd get application todolist-app     # Synced / Healthy

# 3. Acesso externo (R3)
curl -I http://localhost/                          # HTTP 302 (redirect /login)
curl -s http://localhost/login | head -20          # HTML da página de login

# 4. Escalabilidade/resiliência (R4)
kubectl get hpa -n todolist -o wide                # Deployment/todolist-app, 2/10, cpu/mem
kubectl get pdb -n todolist                        # MIN AVAILABLE 1
kubectl get deploy -n todolist -o wide             # réplicas gerenciadas pelo HPA

# 5. Health check (R4)
kubectl exec -n todolist deploy/todolist-app -- curl -s http://localhost:5000/healthz  # ok

# 6. UI (R3)
# http://localhost/        → página de login (login: admin / admin123)
# https://localhost:8080   → ArgoCD (senha: make argocd-password)

# 7. Documentação (R5)
# https://nikolastsdev.github.io/platform-engineer/arquitetura.html
```

**Exemplo de deploy de nova versão (R2):** qualquer push em `main` dispara test → build → deploy; o commit `chore: promove imagem ... [skip ci]` aparece no histórico e o ArgoCD sincroniza. Para demonstrar ao vivo, basta um push (ex.: mudar `APP_COLOR` no `values.yaml`) e mostrar o `git log` + `kubectl get pods` sendo reciclados.

---

## 8. Referência rápida de comandos do projeto

```bash
make create            # provisiona tudo (init + apply + outputs)
make destroy           # destrói cluster + limpa containers/kubeconfig
make reset             # destroy + create
make clean             # remove state local do Terraform
make argocd-password   # senha do admin do ArgoCD
```

---

*Última atualização: acompanha o estado atual do repositório (Kind v1.30.0, ArgoCD 7.4.0, Helm chart `k8s/helm/todolist-app`).*