# Modelo C4 — todolist-app

Referência: [C4-PlantUML / C4 Model](https://c4model.info/)

## C1 — Context (Sistema como caixa preta)

```mermaid
graph LR
    U["👤 Usuário<br/>(navegador)"] -->|"http://localhost:8080"| S["📦 Sistema todolist-app"]
    S -->|"SQL| TCP:5432"| DB["🐘 PostgreSQL"]
    DEV["💻 Dev / CI"] -->|"git push"| GIT["📁 Repo GitHub"]
    GIT -->|"Flux CD"| S
```

## C2 — Container (Componentes internos, 1 nível de detalhe)

```mermaid
graph TB
    subgraph "Namespace: todolist"
        APP["Flask App<br/>(Gunicorn 2 workers)"]
        SVC["Service ClusterIP"]
        INGRESS["NGINX Ingress"]
        HPA["HorizontalPodAutoscaler"]
        PDB["PodDisruptionBudget"]
        CRON["CronJob cleanup"]
    end
    subgraph "Namespace: todolist-db"
        PG["PostgreSQL 15"]
    end
    subgraph "Namespace: ingress-nginx"
        NG["NGINX Controller"]
    end
    APP --> SVC --> NG
    APP --> PG
    HPA -.-> APP
    PDB -.-> APP
```

## C3 — Component (Dentro do App — código)

```mermaid
graph LR
    subgraph "Flask Application (app.py)"
        LOGIN["Login / Auth"]
        INDEX["List Todos"]
        ADD["Add Task"]
        TOGGLE["Toggle Done"]
        DEL["Delete"]
        PODS["Pods View (K8s API)"]
        CLEANUP["Cleanup (CronJob trigger)"]
        HEALTH["Healthz / DB check"]
    end
    DB["SQLAlchemy / PostgreSQL"]
    K8S["Kubernetes API
    (via ServiceAccount)"]
    LOGIN --> INDEX --> ADD --> TOGGLE --> DEL
    INDEX --> PODS --> K8S
    CLEANUP --> DB
```

## Legenda

- **C1:** Quem usa o sistema (usuário, dev) e o que ele faz
- **C2:** Os containers/namespaces que compõem a solução (deploy, db, ingress)
- **C3:** Componentes internos da aplicação (módulos Flask)
