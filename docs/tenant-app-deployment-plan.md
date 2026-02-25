# Tenant Application Deployment Plan

**Status:** Planning
**Created:** 2026-02-24
**Updated:** 2026-02-24

## Overview

Deploy 5 tenant applications to the k3s cluster using ArgoCD for GitOps delivery. Apps will share a multi-tenant PostgreSQL instance following the isolation pattern documented in `/Users/xavierlopez/Dev/pg`.

## Applications

| App | Type | Ports | Dependencies | Access | Notes |
|-----|------|-------|--------------|--------|-------|
| **oracle** | Python worker | None | PostgreSQL | Internal | Has Helm chart |
| **panchito** | Flask ETL API | 80, 8000 | PostgreSQL, Redis | External | Phase 2 in progress |
| **rigoberta** | Rails 8 web | 3000 | PostgreSQL, Redis | External | Action Cable (websockets) |
| **thehouseguy** | Rails 8 web | 3000 | PostgreSQL, Redis, S3 | External | Real estate platform |
| **data-pipelines** | Airflow ETL | None | PostgreSQL, Airflow | Internal | Batch jobs |

## Architecture Decisions

### 1. Manifest Location: **Centralized in gitops repo**

**Decision:** Store Kubernetes manifests in `apps/` directory within this gitops repository.

**Rationale:**
- Single source of truth for platform deployment configuration
- Platform engineer managing all 5 apps (not separate teams)
- Easier to enforce platform standards (Istio, resource limits, security policies)
- Aligns with existing pattern (Big Bang, platform services managed here)
- ArgoCD Applications reference paths in this repo

**Directory Structure:**
```
gitops/
├── apps/
│   ├── panchito/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── virtualservice.yaml
│   │   └── sealed-secret.yaml
│   ├── oracle/
│   │   ├── helmrelease.yaml (or ArgoCD points to chart in oracle repo)
│   │   └── sealed-secret.yaml
│   ├── rigoberta/
│   ├── thehouseguy/
│   └── data-pipelines/
└── argocd/
    └── applications/
        ├── panchito.yaml
        ├── oracle.yaml
        ├── rigoberta.yaml
        ├── thehouseguy.yaml
        └── data-pipelines.yaml
```

### 2. Database Strategy: **Shared multi-tenant PostgreSQL**

**Decision:** Deploy single PostgreSQL cluster with database-per-tenant isolation model.

**Existing Design:** Production-grade multi-tenant isolation pattern already exists at `/Users/xavierlopez/Dev/pg`

**Isolation Model:**
- Dedicated database per tenant: `db_panchito`, `db_oracle`, `db_rigoberta`, `db_thehouseguy`, `db_data_pipelines`
- Dedicated login role per tenant: `panchito_app`, `oracle_app`, etc.
- Dedicated schema inside each database: `app`
- Exclusive access to own schema only
- No cross-tenant access (tested and validated)
- Locked-down public schema
- Hardened default privileges

**Benefits:**
- Cost optimization (single RDS instance vs 5 instances)
- Proven isolation with test suite
- Compliance-ready (NIST 800-53, FedRAMP Moderate)
- Portable from k8s → RDS/Aurora
- Dog-fooding (validating the pattern in production for our own use)

### 3. Container Images: **From OCI image build pipeline**

**Decision:** Images will come from soon-to-exist OCI image build pipeline.

**Pipeline Requirements:**
- [ ] Automated builds from app repositories
- [ ] Semantic versioning tags
- [ ] Push to proper registry (GitHub Container Registry, GitLab Registry, or private registry)
- [ ] Non-root user specified in Dockerfile
- [ ] Health check endpoints implemented
- [ ] No secrets baked into image
- [ ] Reasonable image size (< 500MB ideally)
- [ ] Multi-stage builds used
- [ ] Vulnerability scanning integrated

**Temporary State:**
- Existing images may be used for initial deployment
- Pipeline will be built separately
- Apps can be redeployed with new images once pipeline is operational

### 4. Deployment Order: **oracle → panchito → rigoberta → thehouseguy → data-pipelines**

**Rationale:**

1. **oracle** (FIRST - easiest win)
   - Already has Helm chart at `/Users/xavierlopez/Dev/oracle/charts/oracle-worker/`
   - Internal-only worker (no Service/VirtualService needed)
   - Simple: just PostgreSQL connection
   - Validates: ArgoCD → Helm chart → PostgreSQL workflow

2. **panchito** (SECOND - validates external access)
   - Flask app (simpler than Rails)
   - Web-facing (validates Istio VirtualService + ingress)
   - PostgreSQL + Redis
   - Tests complete external access path through Cloudflare Tunnel

3. **rigoberta** (THIRD - Rails reference template)
   - Rails 8 with Action Cable (websockets)
   - More complex than Flask (realtime features)
   - Good learning ground for thehouseguy deployment
   - Tests Action Cable through Istio

4. **thehouseguy** (FOURTH - production Rails app)
   - Rails 8 production application
   - Optional S3 integration
   - Benefits from lessons learned on rigoberta
   - Real estate listing platform

5. **data-pipelines** (LAST - most complex)
   - Requires Airflow deployment (operator or standalone)
   - Batch jobs as CronJobs/Jobs
   - Can leverage working PostgreSQL from other apps
   - Most complex scheduling requirements

## Implementation Steps

### Phase 1: PostgreSQL Foundation

**Goal:** Deploy multi-tenant PostgreSQL cluster with tenant isolation.

**Steps:**

1. **Deploy PostgreSQL to cluster**
   - Use Bitnami PostgreSQL Helm chart
   - Deploy to `platform` namespace
   - Configure persistence (PVC)
   - Set resource limits

2. **Initialize tenant databases**
   - Adapt `/Users/xavierlopez/Dev/pg/init/01_init_tenants.sql`
   - Add all 5 tenant databases:
     - `db_panchito` + `panchito_app` role
     - `db_oracle` + `oracle_app` role
     - `db_rigoberta` + `rigoberta_app` role
     - `db_thehouseguy` + `thehouseguy_app` role
     - `db_data_pipelines` + `data_pipelines_app` role
   - Run as init container or Job

3. **Create Sealed Secrets for database credentials**
   - Each app gets dedicated DATABASE_URL
   - Format: `postgresql://tenant_app:password@postgresql.platform.svc.cluster.local:5432/db_tenant`
   - Store as SealedSecret in each app's directory

4. **Verify isolation**
   - Run test suite from `/Users/xavierlopez/Dev/pg/scripts/test_isolation.sh` (adapted for k8s)
   - Validate no cross-tenant access

**Files to create:**
- `platform/postgresql/kustomization.yaml`
- `platform/postgresql/helmrelease.yaml`
- `platform/postgresql/init-job.yaml`
- `apps/{app}/sealed-secret.yaml` (x5)

### Phase 2: Deploy oracle (First App)

**Goal:** Deploy simplest app to validate ArgoCD + PostgreSQL workflow.

**Steps:**

1. **Enhance oracle Helm chart**
   - Add resource limits/requests
   - Add Sealed Secret reference for DATABASE_URL
   - Add Istio sidecar injection label
   - Update image registry in values
   - Add liveness/readiness probes (if applicable)

2. **Create ArgoCD Application**
   - Application manifest at `argocd/applications/oracle.yaml`
   - Points to Helm chart in oracle repo or copied to `apps/oracle/`
   - Auto-sync enabled
   - Target namespace: `oracle` or `apps`

3. **Deploy and verify**
   - Commit and push
   - ArgoCD syncs automatically
   - Check pod logs for successful DB connection
   - Verify Istio sidecar injected

**Files to create/modify:**
- `argocd/applications/oracle.yaml`
- `/Users/xavierlopez/Dev/oracle/charts/oracle-worker/values.yaml` (update)
- `/Users/xavierlopez/Dev/oracle/charts/oracle-worker/templates/deployment.yaml` (enhance)

### Phase 3: Deploy panchito (Validates External Access)

**Goal:** Deploy web-facing Flask app with full ingress path.

**Steps:**

1. **Create Kubernetes manifests**
   - Deployment (Flask + Nginx containers or single container)
   - Service (ClusterIP, ports 80 and 8000)
   - VirtualService (Istio ingress, host: `panchito-sandbox.zavestudios.com`)
   - Sealed Secret (DATABASE_URL, Redis connection)

2. **Configure Redis**
   - Option A: Deploy shared Redis to platform namespace
   - Option B: Redis per app (more isolation)
   - Add Redis connection to Sealed Secret

3. **Create ArgoCD Application**
   - Application manifest at `argocd/applications/panchito.yaml`
   - Points to `apps/panchito/` in this repo
   - Kustomize or raw manifests

4. **Deploy and verify**
   - Commit and push
   - ArgoCD syncs
   - Test external access: `https://panchito-sandbox.zavestudios.com`
   - Verify logs show DB + Redis connections

**Files to create:**
- `apps/panchito/kustomization.yaml`
- `apps/panchito/deployment.yaml`
- `apps/panchito/service.yaml`
- `apps/panchito/virtualservice.yaml`
- `apps/panchito/sealed-secret.yaml`
- `argocd/applications/panchito.yaml`
- `platform/redis/` (if shared Redis)

### Phase 4: Deploy rigoberta (Rails Template)

**Goal:** Deploy Rails 8 app with Action Cable websockets.

**Steps:**

1. **Create Kubernetes manifests**
   - Deployment (Rails app)
   - Service (ClusterIP, port 3000)
   - VirtualService (host: `rigoberta-sandbox.zavestudios.com`)
   - Sealed Secret (DATABASE_URL, Redis, SECRET_KEY_BASE)

2. **Configure Action Cable**
   - Ensure VirtualService supports websocket upgrade headers
   - Redis adapter for Action Cable

3. **Database migrations**
   - Option A: Init container runs migrations
   - Option B: Separate Job for migrations
   - Update oracle pattern if needed

4. **Deploy and verify**
   - ArgoCD sync
   - Test web access
   - Test Action Cable connection (websockets)

**Files to create:**
- `apps/rigoberta/` (similar structure to panchito)
- `argocd/applications/rigoberta.yaml`

### Phase 5: Deploy thehouseguy (Production Rails)

**Goal:** Deploy production Rails app with optional S3.

**Steps:**

1. **Create Kubernetes manifests**
   - Similar to rigoberta (Rails 8 pattern)
   - Add S3 configuration if needed (AWS credentials or MinIO)

2. **S3 Integration (optional)**
   - Option A: Use existing AWS S3 bucket
   - Option B: Deploy MinIO to cluster
   - Add S3 credentials to Sealed Secret

3. **Deploy and verify**
   - ArgoCD sync
   - Test real estate listing features
   - Verify file uploads (if S3 enabled)

**Files to create:**
- `apps/thehouseguy/`
- `argocd/applications/thehouseguy.yaml`
- `platform/minio/` (if using MinIO)

### Phase 6: Deploy data-pipelines (Airflow ETL)

**Goal:** Deploy Airflow batch ETL with CronJobs.

**Steps:**

1. **Deploy Airflow**
   - Option A: Use Apache Airflow Helm chart
   - Option B: Deploy standalone scheduler + workers
   - Configure Airflow to use shared PostgreSQL for metadata

2. **Create DAG manifests**
   - CronJobs for scheduled batch ETL
   - Jobs for one-time processing
   - ConfigMaps for DAG definitions

3. **Deploy and verify**
   - ArgoCD sync
   - Test DAG execution
   - Verify ETL writes to `db_data_pipelines`

**Files to create:**
- `platform/airflow/` (Airflow deployment)
- `apps/data-pipelines/` (DAGs, CronJobs)
- `argocd/applications/data-pipelines.yaml`

## Technical Details

### oracle Helm Chart (Current State)

**Location:** `/Users/xavierlopez/Dev/oracle/charts/oracle-worker/`

**Current Chart.yaml:**
```yaml
apiVersion: v2
name: oracle-worker
version: 0.1.0
```

**Current values.yaml:**
```yaml
image:
  repository: registry.gitlab.com/your-group/oracle
  tag: latest

env:
  DATABASE_URL: ""
```

**Current templates/deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oracle-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oracle-worker
  template:
    metadata:
      labels:
        app: oracle-worker
    spec:
      containers:
        - name: worker
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          env:
            - name: DATABASE_URL
              value: "{{ .Values.env.DATABASE_URL }}"
```

**Needed Enhancements:**
- Add resource limits/requests
- Reference Sealed Secret instead of plain text DATABASE_URL
- Add Istio injection label (`sidecar.istio.io/inject: "true"`)
- Update image repository to actual registry
- Add imagePullPolicy
- Add security context (non-root user)

### PostgreSQL Multi-Tenant Pattern

**Reference Implementation:** `/Users/xavierlopez/Dev/pg`

**Key Files:**
- `init/01_init_tenants.sql` - SQL for creating tenant databases, roles, schemas
- `scripts/test_isolation.sh` - Validation test suite
- `docs/ARCHITECTURE.md` - Design details
- `docs/SECURITY.md` - Security controls
- `README.md` - Already references panchito, thehouseguy, rigoberta

**Tenant Initialization Pattern (SQL):**
```sql
-- Create tenant database
CREATE DATABASE db_tenant;

-- Create tenant role
CREATE ROLE tenant_app WITH LOGIN PASSWORD 'secure_password';

-- Connect to tenant database
\c db_tenant

-- Revoke public schema access
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE db_tenant FROM PUBLIC;

-- Create app schema owned by tenant
CREATE SCHEMA app AUTHORIZATION tenant_app;

-- Set search path
ALTER ROLE tenant_app SET search_path TO app, pg_catalog;

-- Grant minimal privileges
GRANT CONNECT ON DATABASE db_tenant TO tenant_app;
GRANT USAGE ON SCHEMA app TO tenant_app;
GRANT ALL ON SCHEMA app TO tenant_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON TABLES TO tenant_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON SEQUENCES TO tenant_app;
```

### Istio VirtualService Pattern (for web-facing apps)

**Example for panchito:**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: panchito
  namespace: apps
spec:
  hosts:
    - panchito-sandbox.zavestudios.com
  gateways:
    - istio-gateway/public
  http:
    - match:
        - uri:
            prefix: /
      route:
        - destination:
            host: panchito.apps.svc.cluster.local
            port:
              number: 80
```

### ArgoCD Application Pattern

**Example for oracle:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: oracle
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/xavierlopez/gitops.git
    targetRevision: main
    path: apps/oracle
  destination:
    server: https://kubernetes.default.svc
    namespace: apps
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Namespace Strategy

**Options:**

### Option A: Single `apps` namespace for all tenant apps
- Simpler RBAC
- Shared service discovery
- Less isolation

### Option B: Namespace per app (`panchito`, `oracle`, etc.)
- Better isolation
- Clearer boundaries
- More complex NetworkPolicies

**Recommendation:** Option B (namespace per app) for stronger isolation boundaries.

## Redis Strategy

**Options:**

### Option A: Shared Redis cluster in `platform` namespace
- Single Redis deployment
- Apps connect to `redis.platform.svc.cluster.local`
- Use database numbers for isolation (db 0, 1, 2, etc.)
- Cost effective

### Option B: Redis per app
- Dedicated Redis in each app's namespace
- Complete isolation
- Higher resource usage

**Recommendation:** Option A (shared Redis) with database number isolation, similar to PostgreSQL pattern.

## Success Criteria

**Phase 1 - PostgreSQL:**
- [ ] PostgreSQL deployed and healthy
- [ ] All 5 tenant databases created
- [ ] Isolation tests pass
- [ ] Sealed Secrets created for all apps

**Phase 2 - oracle:**
- [ ] oracle pod running
- [ ] Successfully connects to `db_oracle`
- [ ] Logs show healthy operation
- [ ] Istio sidecar injected

**Phase 3 - panchito:**
- [ ] Accessible at `https://panchito-sandbox.zavestudios.com`
- [ ] API endpoints responding
- [ ] PostgreSQL + Redis connections working
- [ ] Logs show healthy operation

**Phase 4 - rigoberta:**
- [ ] Accessible at `https://rigoberta-sandbox.zavestudios.com`
- [ ] Action Cable websockets working
- [ ] Database migrations run successfully

**Phase 5 - thehouseguy:**
- [ ] Accessible at `https://thehouseguy-sandbox.zavestudios.com`
- [ ] Listing features working
- [ ] S3 integration working (if enabled)

**Phase 6 - data-pipelines:**
- [ ] Airflow scheduler running
- [ ] DAGs visible and executable
- [ ] Batch jobs completing successfully
- [ ] ETL writing to `db_data_pipelines`

## Known Issues and Considerations

1. **Container Image Production Readiness**
   - Need to assess current images
   - May need to rebuild with security hardening
   - Ensure proper registry and tagging

2. **Database Migration Strategy**
   - Rails apps need migration strategy (init container vs Job)
   - oracle and panchito may have different patterns

3. **S3 for thehouseguy**
   - Optional but recommended for file uploads
   - Need to decide: AWS S3 or MinIO in-cluster

4. **Airflow Complexity**
   - Most complex deployment
   - May need separate design session
   - Consider Airflow Helm chart vs custom deployment

5. **Monitoring and Logging**
   - All apps should emit logs to Alloy → Loki
   - Prometheus metrics via Istio telemetry
   - Grafana dashboards per app

6. **Kyverno Policy Violations**
   - Ensure apps comply with existing policies
   - May need policy exceptions for specific app needs

## Next Session Checklist

When ready to implement:

1. [ ] Run container image assessment commands
2. [ ] Review `/Users/xavierlopez/Dev/pg` for any changes needed
3. [ ] Decide on namespace strategy (A or B)
4. [ ] Decide on Redis strategy (A or B)
5. [ ] Start with Phase 1: PostgreSQL deployment

## References

- **Multi-tenant PostgreSQL:** `/Users/xavierlopez/Dev/pg`
- **oracle Helm chart:** `/Users/xavierlopez/Dev/oracle/charts/oracle-worker/`
- **App repositories:**
  - `/Users/xavierlopez/Dev/panchito`
  - `/Users/xavierlopez/Dev/oracle`
  - `/Users/xavierlopez/Dev/rigoberta`
  - `/Users/xavierlopez/Dev/thehouseguy`
  - `/Users/xavierlopez/Dev/data-pipelines`
- **Big Bang docs:** `/Users/xavierlopez/Dev/bigbang/docs/`
- **ArgoCD:** Deployed at `argocd-sandbox.zavestudios.com`
