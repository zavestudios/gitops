# Tenant Application Deployment Plan

**Status:** Planning
**Created:** 2026-02-24
**Updated:** 2026-03-02

## Purpose

## Current Status Update (2026-03-05)

- `mia` tenant manifests and ArgoCD application wiring are now present in GitOps.
- On-prem tenant layer is enabled in `clusters/on-prem/kustomization.yaml`.
- Runtime verification is intentionally deferred and will be completed via cluster-state inspection.


Define the GitOps-owned rollout sequence for onboarding tenant workloads into the cluster.

This document is intentionally scoped to **gitops repository responsibilities**:
- desired-state structure
- application registration patterns
- promotion/verification flow

Implementation details inside tenant repositories and platform-service repositories are referenced, not authored here.

## Scope Boundaries

This plan defines:
- directory and manifest organization in this repository
- ArgoCD/Flux application registration approach
- sequencing for rollout and validation

This plan does **not** define:
- source code changes in tenant repositories
- Helm chart implementation details in tenant repos
- database schema implementation details in external repos

## Applications

| App | Type | Dependencies | Access |
|-----|------|--------------|--------|
| `oracle` | Python worker | PostgreSQL | Internal |
| `panchito` | Flask API | PostgreSQL, Redis | External |
| `rigoberta` | Rails web | PostgreSQL, Redis | External |
| `thehouseguy` | Rails web | PostgreSQL, Redis, S3 | External |
| `data-pipelines` | Airflow ETL | PostgreSQL, Airflow | Internal |

## GitOps Decisions

### 1. Manifest location

Store tenant runtime state in repository-owned desired-state directories.

Recommended structure:

```text
gitops/
├── tenants/
│   ├── oracle/
│   ├── panchito/
│   ├── rigoberta/
│   ├── thehouseguy/
│   └── data-pipelines/
└── clusters/
    └── <env>/
```

### 2. Application registration

Use one ArgoCD Application per tenant workload.

Pattern:
- Application objects live in GitOps-managed paths.
- Application sources point to approved workload state sources.
- Sync policy and namespace behavior are explicit and reviewable.

### 3. Shared services

Shared services (PostgreSQL, Redis, Airflow platform components, policy layers) remain platform-owned and should be managed in platform-scoped directories.

### 4. Rollout order

Recommended sequence for risk reduction:
1. `oracle`
2. `panchito`
3. `rigoberta`
4. `thehouseguy`
5. `data-pipelines`

## Phased Rollout

### Phase 1: Data and secrets foundation
- Ensure PostgreSQL runtime and tenant credential delivery are represented in GitOps.
- Ensure secret management path is standardized.
- Validate tenant isolation checks through approved test workflows.

### Phase 2: First tenant deployment (`oracle`)
- Register application.
- Reconcile and verify pod health, DB connectivity, and sidecar/policy expectations.

### Phase 3: External web tenant (`panchito`)
- Reconcile deployment + service + ingress/VirtualService.
- Verify external routing and dependency connectivity.

### Phase 4: Rails tenant (`rigoberta`)
- Reconcile runtime and dependency wiring.
- Verify websocket/realtime behavior path.

### Phase 5: Production-shaped Rails tenant (`thehouseguy`)
- Reconcile runtime and optional object-storage integration.
- Verify application feature health.

### Phase 6: Batch/orchestration tenant (`data-pipelines`)
- Reconcile Airflow/DAG scheduling components.
- Verify scheduled execution and data writes.

## Success Criteria

- Each workload is registered and reconciled via GitOps.
- No manual cluster drift is required for steady-state operation.
- Workload health checks pass after reconciliation.
- Promotion/update/rollback remains Git-driven and auditable.

## Cross-Repo Coordination

Cross-repository implementation work must be tracked in linked issues/PRs in the owning repos.

Examples:
- tenant repo runtime/chart updates
- platform-service pipeline updates
- database service changes

This document should reference those issue/PR links instead of embedding workstation paths or direct local edit instructions.

## References

- `platform-docs/_platform/PLATFORM_OPERATING_MODEL.md`
- `platform-docs/_platform/LIFECYCLE_MODEL.md`
- `platform-docs/_platform/REPO_TAXONOMY.md`
- `gitops/docs/dag.md`

## Manual Execution Note

Cluster mutation commands derived from this plan are **Run manually by human**.
