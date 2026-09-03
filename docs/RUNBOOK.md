# Operations Runbook

## Daily Operations

### Checking Application Health

```bash
# Check all pods
kubectl get pods -n todolist -n todolist-db

# Check application logs
kubectl logs -n todolist -l app=todolist --tail=100

# Check database logs
kubectl logs -n todolist-db -l app=postgresql --tail=50

# Verify health endpoint
kubectl exec -n todolist $(kubectl get pod -n todolist -l app=todolist -o jsonpath='{.items[0].metadata.name}') \
  -- curl -s http://localhost:5000/healthz
```

### Monitoring Resource Usage

```bash
# Check HPA status
kubectl get hpa -n todolist

# Show detailed HPA info
kubectl describe hpa todolist-hpa -n todolist

# Check resource consumption
kubectl top pods -n todolist
kubectl top nodes
```

### Viewing Ingress Configuration

```bash
# Check ingress
kubectl get ingress -n todolist
kubectl describe ingress todolist -n todolist

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
```

---

## Troubleshooting

### Application Won't Start

1. **Check database connectivity:**
```bash
kubectl exec -n todolist-db -it $(kubectl get pod -n todolist-db -l app=postgresql -o jsonpath='{.items[0].metadata.name}') \
  -- psql -U todolist -c "SELECT 1"
```

2. **Check secret configuration:**
```bash
kubectl get secret todolist-secrets -n todolist -o yaml
```

3. **Check events:**
```bash
kubectl get events -n todolist --sort-by='.lastTimestamp'
```

### Database Connection Issues

1. **Verify database is running:**
```bash
kubectl get pods -n todolist-db
```

2. **Check database service:**
```bash
kubectl get svc postgresql -n todolist-db
kubectl describe svc postgresql -n todolist-db
```

3. **Test connectivity from app namespace:**
```bash
kubectl run -n todolist --rm -it testdb --image=postgres:15-alpine -- \
  psql -h postgresql.todolist-db.svc.cluster.local -U todolist -c '\l'
```

### Image Pull Issues

1. **Check if image exists in registry:**
```bash
curl http://localhost:5000/v2/todolist/manifests/latest
```

2. **Verify node can reach registry:**
```bash
docker exec kind-control-plane curl http://kind-registry:5000/v2/_catalog
```

3. **Manually pull image to nodes:**
```bash
kind load docker-image localhost:5000/todolist:latest --name todolist-platform
```

### Ingress Not Working

1. **Check ingress controller:**
```bash
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

2. **Verify ingress resources:**
```bash
kubectl get ingress -A
kubectl describe ingress todolist -n todolist
```

3. **Test locally:**
```bash
curl -v http://localhost:8080/healthz
```

### CronJob Not Running

1. **Check CronJob status:**
```bash
kubectl get cronjob -n todolist
kubectl describe cronjob todolist-cleanup -n todolist
```

2. **Check if suspended:**
```bash
kubectl get cronjob todolist-cleanup -n todolist -o jsonpath='{.spec.suspend}'
```

3. **Manually trigger a job:**
```bash
kubectl create job -n todolist --from=cronjob/todolist-cleanup manual-cleanup-test
kubectl logs -n todolist job/manual-cleanup-test
```

---

## Scaling Operations

### Manual Scale (Not Recommended for Production)

```bash
# Scale application
kubectl scale deployment todolist -n todolist --replicas=5

# Scale database (not recommended - use HA solution)
kubectl scale deployment postgresql -n todolist-db --replicas=1
```

### Update HPA Limits

```bash
kubectl patch hpa todolist-hpa -n todolist -p '{"spec":{"maxReplicas":15}}'
```

---

## Deployment Operations

### Rolling Update

```bash
# Trigger rollout (re-pull image)
kubectl rollout restart deployment/todolist -n todolist

# Watch rollout progress
kubectl rollout status deployment/todolist -n todolist

# Rollback if needed
kubectl rollout undo deployment/todolist -n todolist
```

### Update Secrets Safely

```bash
# Update password
kubectl create secret generic todolist-secrets -n todolist \
  --from-literal=DB_PASSWORD='new-password' \
  --dry-run=client -o yaml | kubectl apply -f -

# Trigger restart to pick up new secret
kubectl rollout restart deployment/todolist -n todolist
```

---

## Backup and Recovery

### Database Backup (PostgreSQL)

```bash
# Create backup
kubectl exec -n todolist-db -it $(kubectl get pod -n todolist-db -l app=postgresql -o jsonpath='{.items[0].metadata.name}') \
  -- pg_dump -U todolist todolist > backup-$(date +%Y%m%d-%H%M%S).sql

# Restore from backup
kubectl exec -i -n todolist-db $(kubectl get pod -n todolist-db -l app=postgresql -o jsonpath='{.items[0].metadata.name}') \
  -- psql -U todolist todolist < backup-YYYYMMDD-HHMMSS.sql
```

---

## Cleanup Operations

### Delete Completed Jobs

```bash
# Delete completed pods (CronJob creates finished pods)
kubectl delete pod -n todolist -l job-name --field-selector=status.phase=Succeeded
```

### Manual Cleanup of Tasks

```bash
# Via CLI
curl -X POST -H "X-Cleanup-Token: cleanup-token-change-in-production" \
  http://localhost:8080/cleanup

# Via Kubernetes
kubectl exec -n todolist $(kubectl get pod -n todolist -l app=todolist -o jsonpath='{.items[0].metadata.name}') \
  -- curl -X POST -H "X-Cleanup-Token: cleanup-token-change-in-production" \
  http://localhost/cleanup
```

---

## Disaster Recovery

### Full Cluster Reset

```bash
# 1. Delete all resources
kubectl delete -f k8s/

# 2. Wait for pods to terminate
kubectl wait --for=delete pod --all -A --timeout=60s

# 3. Delete cluster (optional)
kind delete cluster --name todolist-platform

# 4. Run setup again
./scripts/setup.sh
```

### Restore from Git

```bash
# Clone fresh copy
git clone <repository-url> /tmp/platform-engineer
cd /tmp/platform-engineer

# Redeploy
kubectl apply -f k8s/

# Manually trigger image build (if needed)
docker build -t localhost:5000/todolist:latest -f todolist-app/Dockerfile todolist-app/
docker push localhost:5000/todolist:latest

# Restart deployment
kubectl rollout restart deployment/todolist -n todolist
```

---

## Monitoring Commands Cheat Sheet

```bash
# All namespaces
kubectl get all -A

# Watch pods
kubectl get pods -n todolist -w

# Resource usage
kubectl top pods -n todolist
kubectl top nodes

# Events
kubectl get events -A --sort-by='.lastTimestamp'

# Logs aggregation
kubectl logs -n todolist -l app=todolist --tail=-1 --all-containers | tail -100
```
