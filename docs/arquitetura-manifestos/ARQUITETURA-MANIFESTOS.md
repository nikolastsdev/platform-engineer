# Arquitetura de Manifestos YAML — Decisão Final

## Problema Detectado (histórico)
- `k8s/infra/` = Kustomize com `kustomization.yaml` apontando para arquivos **inexistentes** (`app.yaml`, `secrets.yaml`, `configmap.yaml`, `pdb.yaml`, `rbac.yaml`, `ghcr-pull-secret.yaml`).
- Duplicação conceitual entre `k8s/helm/` (templates parametrizáveis) e `k8s/base/` (YAMLs estáticos): o mesmo recurso existia em dois lugares, dessincronizados.
- Falta de separação de camadas e paths errados no CI (`todolist-app/`, `k8s/base/app.yaml`), causando falhas recorrentes.

## Decisão: Helm chart é a ÚNICA fonte de verdade
- `k8s/helm/todolist-app/` declara **todos** os recursos declarativos do cluster.
- `k8s/base/` e `k8s/infra/` foram **removidos** — elimina a duplicação.
- O ArgoCD aponta para `k8s/helm/todolist-app` (auto-detect via `Chart.yaml`).
- O Terraform **não** declara recursos da aplicação: apenas provisiona o cluster (Kind), instala o ArgoCD, configura as credenciais do repo e cria o `ghcr-pull` (secret com PAT local — nunca vai pro Git).

## Princípios de Arquitetura (final)
1. **DRY**: um template Helm por recurso; zero YAML duplicado.
2. **Camadas dentro do chart**: namespaces → database → app → network → cleanup (mesma ordem de aplicação).
3. **Simplicidade**: `values.yaml` parametriza tudo (imagem, réplicas, env, secrets, postgres, cron).
4. **GitOps puro**: o repo Git é a fonte da verdade — mudanças no chart são sincronizadas pelo ArgoCD (selfHeal + prune).
5. **Validação contínua**: `values.schema.json` valida entradas; `helm lint` + `helm unittest` (19 testes) no CI.

## Estrutura Final

```
k8s/
└── helm/
    └── todolist-app/              # ⭐ Fonte única (ArgoCD sync)
        ├── Chart.yaml
        ├── values.yaml            # Parâmetros (imagem, réplicas, env, secrets, db, cron)
        ├── values.schema.json     # Schema JSON (header-only, valida no lint)
        ├── templates/
        │   ├── namespace.yaml         # Namespaces app + db
        │   ├── postgresql.yaml        # PostgreSQL (deploy + service + secret)
        │   ├── deployment.yaml        # Aplicação (probes, securityContext, imagePullSecret)
        │   ├── service.yaml           # Service NodePort
        │   ├── ingress.yaml           # Ingress nginx
        │   ├── hpa.yaml               # HPA (2–10 réplicas)
        │   ├── pdb.yaml               # PDB
        │   ├── configmap.yaml         # Env da app
        │   ├── secret.yaml            # Credenciais da app
        │   ├── serviceaccount.yaml    # Service Account
        │   ├── rbac.yaml              # Role + RoleBinding (pods/cronjobs)
        │   └── cronjob.yaml           # Cleanup periódico
        └── tests/                     # helm-unittest (19 testes + snapshot)
```

## Ordem de Aplicação (significado)
1. **Namespaces** → `todolist` e `todolist-db` (bootstrap também via Terraform para o `ghcr-pull`)
2. **PostgreSQL** → deploy + service + secret no namespace `todolist-db`
3. **App** → deployment (3 réplicas, probes, securityContext), HPA, PDB
4. **Network** → service NodePort, ingress, serviceAccount, RBAC
5. **Cleanup** → CronJob de limpeza (token via secret da app)

## Fluxo GitOps
1. `make create` → Terraform: Kind cluster + ArgoCD + credenciais + `ghcr-pull` secret
2. ArgoCD (Application `todolist-app`) → aponta para `k8s/helm/todolist-app` no repo
3. Qualquer push no repo (app ou chart) → ArgoCD detecta e sincroniza (selfHeal + prune)
4. CI (`ci.yaml`) → test → build → scan → **promove imagem** no `values.yaml` (tag por SHA) → push → ArgoCD aplica

## Validação
- `helm lint .` → 0 falhas
- `helm template --namespace todolist .` → 17 recursos (com pull-secret) / 16 (sem credenciais), nenhum em `default`
- `helm unittest .` → 19/19 pass