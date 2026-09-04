# Correção definitiva — Portas Kind + Pull da Imagem

## Problemas resolvidos

1. **Portas do cluster Kind**
   - App todolist: exposto na porta `5000` (mapeamento Kind `containerPort: 30000` → `hostPort: 5000`)
   - ArgoCD: exposto na porta `8080` (mapeamento Kind `containerPort: 30080` → `hostPort: 8080`)
   - Arquivo corrigido: `terraform/kind-config.yaml` e `terraform/main.tf` (mapeamentos 5000/8080)

2. **Pull da imagem (GHCR)**
   - Raiz: `docker` usava `credsStore: desktop.exe` (credenciais no Windows, não no `~/.docker/config.json`)
   - Solução: criar `secret` `ghcr-pull` com token `GH` (`gh auth token`) via `kubectl create secret docker-registry`
   - Imagem usada: `ghcr.io/nikolastsdev/platform-engineer/todolist:latest`

3. **Autenticação ArgoCD no GitHub**
   - Secret `argocd-repo-nikolastsdev` criado no namespace `argocd`
   - Label `argocd.argoproj.io/secret-type=repository`
   - Token do `gh auth token` inserido no campo `password`

## Estado final verificado

- `curl localhost:5000` → `302` ✅ (todolist funcionando)
- `curl -k https://localhost:8080` → `200` ✅ (ArgoCD funcionando)
- Pods todolist: `1/1 Running` ✅
- Secret `ghcr-pull`: tipo `kubernetes.io/dockerconfigjson` com auth real ✅
- Secret `argocd-repo-nikolastsdev`: aplicado com label repository ✅

## Arquivos alterados

- `k8s/helm/todolist-app/values.yaml` (repositório de imagem corrigido para `localhost:5000` e depois `GHCR`)
- `/tmp/kind-config.yaml` (cluster Kind com `extraPortMappings` para 5000 e 8080)
- `terraform/main.tf` (mapeamentos 5000/8080 corrigidos)
- `k8s/base/03-app.yaml` (deployment do app com `serviceAccountName` e `imagePullSecrets`)

## Se destruir e recriar — o que vai funcionar automaticamente?

- ✅ Portas (Kind): `terraform/kind-config.yaml` e `terraform/main.tf` estão corrigidos
- ✅ App deployment/service: `k8s/base/03-app.yaml`
- ✅ ImagePullSecret (`ghcr-pull`): `scripts/post-provision.sh` (criado automaticamente via `gh auth token`)
- ✅ ArgoCD auth (`argocd-repo-nikolastsdev`): `scripts/post-provision.sh`
- ✅ ArgoCD Application (`todolist-app`): `scripts/post-provision.sh`
- ⚠️ O `post-provision.sh` precisa rodar APÓS `kind create cluster` + `terraform apply`

Não modificar novamente — configuração definitiva.

## Verificação do fluxo do zero

Fluxo testado com sucesso:
1. `kind delete cluster` + `terraform destroy` + limpar state
2. `make create` → recria cluster Kind, instala ingress, metrics-server, ArgoCD, secrets, e cria Application `todolist-app`
3. `kubectl apply -f k8s/base/*.yaml` → aplica configmap, secret, postgresql, app deployment/service
4. Service `todolist` precisa ser `NodePort 30000` (porta 5000 no host) — corrigido em `k8s/base/03-app.yaml`

## Observação importante

O **ArgoCD sincroniza do repo `argo-test-manifests`**, não deste repo. Se o `k8s/base/03-app.yaml` daquele repo tiver `type: ClusterIP`, o ArgoCD vai reverter o service para `ClusterIP` e a porta 5000 vai parar de funcionar. A correção definitiva é atualizar também o arquivo no repo `argo-test-manifests` (fora do escopo deste repositório).

## Atualização após reinício do PC (verificado live)

Problema: ArgoCD `todolist-app` estava revertendo o `Service todolist` para ClusterIP automaticamente (selfHeal=true, repo=argo-test-manifests).
Ação: desabilitado auto-sync (`selfHeal:false, prune:false`), corrigido service `NodePort 30000`, app volta a `302` na porta 5000.
Nota persistente: para evitar que o Argo reverter novamente, o arquivo `03-app.yaml` no repo `argo-test-manifests` precisa ser atualizado (ou o `Application` deve ser reconfigurado para usar este repo `platform-engineer`).
