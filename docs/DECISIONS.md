# Architecture Decision Records (ADRs)

## ADR-001: Local Kubernetes Cluster with KIND

**Context:** No cloud account available, need Kubernetes environment for challenge.

**Decision:** Use KIND (Kubernetes IN Docker) for local cluster provisioning.

**Consequences:**
- ✓ No cloud costs
- ✓ Self-contained environment
- ✓ Fast cluster creation/teardown
- ✓ Reproducible for presentation
- ✗ Not suitable for production
- ✗ Limited resource isolation

**Alternatives considered:**
- minikube: Less control over multi-node setup
- k3s: Different from production Kubernetes
- Cloud providers: Requires account/credit card

---

## ADR-002: Terraform for Infrastructure as Code

**Context:** Need repeatable, automated provisioning.

**Decision:** Use Terraform with kind provider for cluster provisioning.

**Consequences:**
- ✓ Industry standard for IaC
- ✓ Declarative configuration
- ✓ Plan before apply
- ✓ State management
- ✗ kind provider has limited features
- ✗ Some steps still require shell commands

**Why not shell-only scripts:**
- Terraform provides plan/apply workflow
- Easier to audit and version control
- Integrates with CI/CD

---

## ADR-003: NGINX Ingress Controller

**Context:** Need external access to application.

**Decision:** Deploy NGINX Ingress Controller via Helm.

**Consequences:**
- ✓ Most widely adopted ingress
- ✓ Rich feature set (rewrite, authentication, rate limiting)
- ✓ Active community
- ✓ Native Kubernetes CRDs

**Alternatives considered:**
- Traefik: Simpler, but less enterprise features
- Ambassador: Edge Stack requires license
- Kong: Overkill for single application

---

## ADR-004: PostgreSQL as StatefulSet with EmptyDir

**Context:** Application requires PostgreSQL database.

**Decision:** Deploy PostgreSQL 15 as a single instance with emptyDir volume.

**Consequences:**
- ✓ Simple deployment
- ✓ Automatic schema creation
- ✓ Data persists while pod is running
- ✗ No high availability
- ✗ Data lost on pod deletion
- ✗ No automated backups

**Production considerations:**
- Use PostgreSQL Operator (e.g., CrunchyData)
- PersistentVolumeClaim with storage class
- Point-in-time recovery
- Automated backups to object storage

---

## ADR-005: Horizontal Pod Autoscaler (HPA) v2

**Context:** Need automatic scaling for resilience.

**Decision:** Deploy HPA targeting CPU (70%) and memory (80%) utilization.

**Consequences:**
- ✓ Built-in Kubernetes feature
- ✓ No external dependencies
- ✓ Scales between 2-10 replicas
- ✓ Zero manual intervention

**Configuration:**
- Minimum replicas: 2 (ensures availability during updates)
- Maximum replicas: 10 (prevents resource exhaustion)
- CPU target: 70% average utilization
- Memory target: 80% average utilization

---

## ADR-006: Local Docker Registry

**Context:** Need to store and distribute container images without external registry.

**Decision:** Deploy local Docker registry accessible at `localhost:5000`.

**Consequences:**
- ✓ Self-contained solution
- ✓ Fast image pushes
- ✓ No authentication required
- ✗ Manual certificate management
- ✗ No image retention policies

**Configuration:**
- Registry name: `kind-registry`
- Port: 5000
- Connected to `kind` Docker network
- Images tagged: `localhost:5000/todolist:latest`

---

## ADR-007: CronJob for Task Cleanup

**Context:** Application requires periodic cleanup of completed tasks.

**Decision:** Deploy CronJob that calls cleanup endpoint every 5 minutes.

**Implementation:**
- Uses curlimages/curl for minimal image size
- Reads cleanup token from service account
- SuccessfulJobsHistoryLimit: 3
- FailedJobsHistoryLimit: 1

**Alternatives considered:**
- Kubernetes native cleanup: Not implemented in app
- External scheduler: Overkill for single endpoint
- Application-level scheduler: Would require code changes

---

## ADR-008: GitOps-ready Structure with Kustomize

**Context:** Need organized manifests that can evolve to GitOps.

**Decision:** Use numbered prefix convention (00-, 01-, etc.) for ordering.

**Consequences:**
- ✓ Clear execution order
- ✓ Easy to migrate to Kustomize overlays
- ✓ Simple for manual deployments
- ✗ Less powerful than Kustomize

**Future migration:**
```
base/
  ├── deployment.yaml
  └── service.yaml
overlays/
  ├── staging/
  │   └── kustomization.yaml
  └── production/
      └── kustomization.yaml
```

---

## ADR-009: ServiceAccount with RBAC for Application

**Context:** Application queries Kubernetes API for pod list.

**Decision:** Create dedicated ServiceAccount with minimal Role permissions.

**Permissions:**
- `get`, `list` on pods (for pod listing feature)
- `get`, `list`, `patch` on cronjobs/jobs (for cleanup status)

**Security considerations:**
- Principle of least privilege
- Namespace-scoped (not ClusterRole)
- No write access to other resources

---

## ADR-010: Trivy for Security Scanning

**Context:** Need vulnerability scanning in CI/CD pipeline.

**Decision:** Integrate Trivy scanner in build workflow.

**Consequences:**
- ✓ Free and open source
- ✓ Native GitHub Security integration
- ✓ Fast scanning
- ✓ Comprehensive vulnerability database

**Configuration:**
- Scan on CRITICAL and HIGH severity
- Fail build on vulnerabilities
- Upload results to SARIF for GitHub Security tab
