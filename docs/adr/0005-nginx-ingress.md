# ADR 0005: NGINX como Ingress Controller

## Status
**Aprovado**

## Contexto
A aplicação precisa ser acessível de fora do cluster pelo navegador (R3). Kind expõe NodePort mas não cria automaticamente um ingress controller.

## Decisão
Usar [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/) (Helm chart oficial) com NodePort 80/443 mapeados para host 8080/8443 via `extraPortMappings`.

## Consequências

- ✅ NGINX é o ingress mais maduro e documentado
- ✅ Suporta TLS, rewrites, rate-limit, basic-auth
- ❗ Adiciona pod controller (consome recursos)
- ❗ Em cloud usaria LoadBalancer; aqui NodePort serve
