# ADR 0001: Cluster local (Kind)

## Status
**Aprovado**

## Contexto
O desafio do PDF (`DESAFIO-PLATFORM-ENGINEER.pdf`) permite rodar localmente desde que seja Kubernetes. Não temos conta de nuvem (AWS/GCP/Azure) disponível no ambiente de desenvolvimento.

## Decisão
Usar [Kind](https://kind.sigs.k8s.io/) (Kubernetes IN Docker) como cluster local para desenvolvimento, testes e demonstração.

## Consequências

- ✅ Nenhum custo de nuvem
- ✅ Criação em segundos (`kind create cluster`)
- ✅ Mesma API Kubernetes (kubectl funciona igual)
- ❗ Não simula multi-AZ, load balancer externo ou redes complexas
- ❗ Persistência de dados limitada (local volume)
