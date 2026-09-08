# Roteiro de Prints — Evidências de Execução

> Roteiro para capturar as evidências do fluxo completo (PDF seção 8, item 4: "logs, screenshots, etc.").
> A cada passo: **rode o comando, espere terminar, tire o print da tela/terminal**, salve com o nome indicado e envie.
> Terminais: maximize a janela antes de printar, para o output caber inteiro.

---

## Fase 0 — Preparação (2 prints)

### 0.1 Raiz do repositório
| | |
|---|---|
| Ação | `pwd` e `ls -la` na raiz do projeto |
| Print | A pasta raiz com `README.md`, `terraform/`, `k8s/`, `docs/`, `Makefile` |
| Arquivo | `00-repo-root.png` |
| Prova | Entregável: repositório estruturado |

### 0.2 Requisitos documentados
| | |
|---|---|
| Ação | Abrir `README.md` no editor/visualizador |
| Print | A tabela "Requisitos atendidos" (R1–R5) |
| Arquivo | `00b-readme-requisitos.png` |
| Prova | R5: documentação |

---

## Fase 1 — Destruir ambiente (prova que é repetível) — *opcional*

> Se quiser provar o processo do zero (recomendado). Se não quiser derrubar o cluster atual, pule para a Fase 2.

### 1.1 `make destroy`
| | |
|---|---|
| Ação | `make destroy` no terminal |
| Print | Output completo (limpeza do cluster, kubeconfig, containers) |
| Arquivo | `01-make-destroy.png` |
| Prova | R1: processo repetível, sem passos manuais |

### 1.2 Cluster removido
| | |
|---|---|
| Ação | `kubectl config get-contexts` e `docker ps` |
| Print | Nenhum cluster kind; nenhum container `todolist-platform-*` |
| Arquivo | `02-cluster-removido.png` |
| Prova | R1: destroy automatizado |

---

## Fase 2 — Provisionar do zero (R1)

### 2.1 `make create` — provisionamento completo
| | |
|---|---|
| Ação | `make create` no terminal (demora ~3–5 min) |
| Print | **Output completo do início ao fim** — `terraform init` → `apply` → "Apply complete! Resources: 6 added" |
| Arquivo | `03-make-create.png` |
| Prova | R1: cluster + infra + dependências por código, sem passos manuais |

### 2.2 Nodes do cluster
| | |
|---|---|
| Ação | `kubectl get nodes -o wide` |
| Print | 4 nodes `Ready` (control-plane + 3 workers) |
| Arquivo | `04-nodes.png` |
| Prova | R1: cluster de 4 nodes provisionado |

### 2.3 Componentes em execução
| | |
|---|---|
| Ação | `kubectl get pods -A` |
| Print | ArgoCD, ingress-nginx, metrics-server, postgresql, todolist-app — todos Running/Completed |
| Arquivo | `05-pods-all.png` |
| Prova | R1/R2: dependências + app no ar |

---

## Fase 3 — Deploy GitOps (R2)

### 3.1 ArgoCD Application (CLI)
| | |
|---|---|
| Ação | `kubectl -n argocd get application todolist-app` |
| Print | `SYNC STATUS: Synced` e `HEALTH STATUS: Healthy` |
| Arquivo | `06-argocd-app-cli.png` |
| Prova | R2: deploy automatizado via GitOps |

### 3.2 ArgoCD UI
| | |
|---|---|
| Ação | Abrir `http://argocd.localhost/` no navegador. Login: `admin`, senha: rode `make argocd-password` |
| Print | UI do ArgoCD com a app `todolist-app` **Synced / Healthy** (triângulo verde no diagrama) |
| Arquivo | `07-argocd-ui.png` |
| Prova | R2/R3: GitOps operacional, acessível externamente |

---

## Fase 4 — Acesso externo (R3)

### 4.1 App no navegador
| | |
|---|---|
| Ação | Abrir `http://localhost/` no navegador |
| Print | Página de **Login — TodoList Platform** renderizada |
| Arquivo | `08-app-login.png` |
| Prova | R3: aplicação acessível pelo navegador |

### 4.2 App após login (opcional, app local sem credenciais obrigatórias)
| | |
|---|---|
| Ação | Se a app permitir, logar/criar tarefa; senão manter o print do login |
| Print | Tela de uso da aplicação (lista de tarefas) |
| Arquivo | `08b-app-uso.png` |
| Prova | R3: app funcional pelo navegador |

### 4.3 Acesso por CLI (complementar)
| | |
|---|---|
| Ação | `curl -I http://localhost/` e `curl -s http://localhost/login \| head -20` |
| Print | HTTP 302 → 200 e HTML da página |
| Arquivo | `09-curl-acesso.png` |
| Prova | R3: acesso externo (mesmo caminho do navegador) |

---

## Fase 5 — Escalabilidade e resiliência (R4)

### 5.1 HPA
| | |
|---|---|
| Ação | `kubectl get hpa -n todolist -o wide` |
| Print | Referência `Deployment/todolist-app`, MINPODS 2, MAXPODS 10, coletando cpu/mem |
| Arquivo | `10-hpa.png` |
| Prova | R4: autoscaling configurado e ativo |

### 5.2 PDB + replicas
| | |
|---|---|
| Ação | `kubectl get pdb -n todolist` e `kubectl get deploy -n todolist` |
| Print | PDB `MIN AVAILABLE 1`; deployment com réplicas |
| Arquivo | `11-pdb-deploy.png` |
| Prova | R4: resiliência (disruptions controlados) |

---

## Fase 6 — Documentação e entregáveis (R5 / seção 8)

### 6.1 Histórico de commits
| | |
|---|---|
| Ação | `git log --oneline -20` e `git status` |
| Print | Histórico de commits da entrega + working tree |
| Arquivo | `12-git-log.png` |
| Prova | Entregável: repositório com histórico de commits |

### 6.2 README (índice/caminho de execução)
| | |
|---|---|
| Ação | Abrir `README.md` |
| Print | Seção "Índice" + "Execução" |
| Arquivo | `13-readme-execucao.png` |
| Prova | R5: README com caminho de execução e índice |

### 6.3 Registro de decisões
| | |
|---|---|
| Ação | Abrir `docs/decisoes/escopo-decisoes.md` |
| Print | Argumento do ambiente Kind + seção de desafios |
| Arquivo | `14-decisoes.png` |
| Prova | R5 / seção 8: registro de decisões e desafios |

---

## Checklist final

- [ ] 00-repo-root.png
- [ ] 00b-readme-requisitos.png
- [ ] 01-make-destroy.png (opcional)
- [ ] 02-cluster-removido.png (opcional)
- [ ] 03-make-create.png
- [ ] 04-nodes.png
- [ ] 05-pods-all.png
- [ ] 06-argocd-app-cli.png
- [ ] 07-argocd-ui.png
- [ ] 08-app-login.png
- [ ] 08b-app-uso.png (opcional)
- [ ] 09-curl-acesso.png
- [ ] 10-hpa.png
- [ ] 11-pdb-deploy.png
- [ ] 12-git-log.png
- [ ] 13-readme-execucao.png
- [ ] 14-decisoes.png

> Obs.: o cluster está no ar agora. Se pular a Fase 1, os prints da Fase 2 em diante saem do cluster atual.