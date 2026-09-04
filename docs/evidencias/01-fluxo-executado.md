=== FLUXO EXECUTADO ===
Data: 2026-09-04T17:03:43-03:00
Comandos: make create (após fix do python YAML) -> verify -> ingress corrigido (porta 5000) + PDB adicionada -> DECISOES atualizado
Estado do cluster: Running (kind, 4 nodes)
ArgoCD: Running (8 pods) | App: Progressing (imagem ainda pull)
DB: Running | Namespaces: todolist, todolist-db, argocd, ingress-nginx
Corrigido no fluxo: terraform/main.tf (python YAML), k8s/base/ingress.yaml (porta), k8s/base/pdb.yaml + kustomization.yaml, docs/DECISOES.md (Flux->ArgoCD)
