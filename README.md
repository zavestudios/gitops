# ZaveStudios GitOps

GitOps source of truth for the ZaveStudios platform.

This repository defines desired cluster state for platform services and tenant workloads. Flux reconciles manifests from this repository into Kubernetes.

**Repository Category:** `infrastructure` (canonical classification in [REPO_TAXONOMY.md](https://github.com/zavestudios/platform-docs/blob/main/_platform/REPO_TAXONOMY.md))

## Scope

- Cluster-level platform resources (`platform/`)
- Environment overlays (`clusters/`)
- Platform service bundles (`bigbang/`)
- Tenant app composition (`tenants/`)
- Operational helper scripts (`tools/`)

## Repository Layout

```text
.
├── clusters/
│   └── on-prem/
│       ├── bigbang-kustomization.yaml
│       ├── kustomization.yaml
│       ├── platform-core-kustomization.yaml
│       └── platform-runtime-kustomization.yaml
├── platform/
│   ├── core/
│   ├── kustomization.yaml
│   ├── namespaces/
│   ├── runtime/
│   └── vault/
├── bigbang/
│   ├── kustomization.yaml
│   ├── gitrepository.yaml
│   ├── helmrelease.yaml
│   ├── namespace.yaml
│   └── values.yaml
├── tenants/
├── docs/
└── tools/
```

## Reconciliation Model

- `clusters/<env>/kustomization.yaml` is the environment entrypoint.
- Environment entrypoint now creates ordered Flux `Kustomization` resources.
- `platform/core` reconciles first.
- `bigbang` reconciles second.
- `platform/runtime` reconciles after Big Bang so CRD-backed resources do not race their controllers.
- Tenant workloads remain reconciled by ArgoCD Applications under `platform/argocd/applications/`.

## Big Bang Integration

`bigbang/` contains Flux resources for deploying Big Bang in a controlled, reproducible way:

- `GitRepository` pins an explicit Big Bang tag.
- `Kustomization` reconciles Big Bang `./base` path.
- `configMapGenerator` injects environment-specific values from `values.yaml`.

The current on-prem values prioritize a minimal package set and public image sources.

## Bootstrap and Apply

Run these from a workstation with cluster access:

**Requires cluster access:**

```bash
# Validate kustomization composition
kubectl kustomize clusters/on-prem

# Apply baseline platform resources
kubectl apply -k clusters/on-prem
```

Reconciliation order is managed by Flux `dependsOn` relationships under `clusters/on-prem/`.

## Workflow

1. Create branch and commit manifest change.
2. Validate manifest rendering locally.
3. Open PR and review reconciliation impact.
4. Merge to main.
5. Flux reconciles to cluster.

## Documentation

- `docs/edge-exposure-plan.md`: Plan for reducing wildcard tunnel exposure and moving to an explicit hostname allowlist with edge protection for operator UIs.
- `docs/bigbang-exit-plan.md`: Execution epic for migrating platform package ownership away from the Big Bang umbrella chart toward directly owned Flux primitives.
- `docs/environment-semantics-plan.md`: Plan for renaming the current persistent environment and introducing a true local sandbox.
- `docs/platform-stability-gap-analysis-2026-06.md`: Pause-and-inventory plan for stabilizing the current platform baseline before deeper app work.
- `docs/image-registry-mappings.md`: Public image mapping used for Big Bang sandbox deployments.
- `docs/keycloak-recovery-notes.md`: Recovery notes for the Keycloak bring-up, including manual incident actions and durable follow-up fixes.
- `docs/argocd-sso-keycloak-runbook.md`: Normal login, role mapping, break-glass, and rollback flow for ArgoCD SSO through Keycloak.
- `docs/rabbitmq-capability-evaluation.md`: Cross-repo decision record for the OpenShift Local RabbitMQ proving exercise and the current defer-promote recommendation.
- `docs/vault-hardening-plan.md`: Vault persistence, lifecycle, and recovery hardening plan for the current environment.
- `docs/vault-migration-plan.md`: Vault, External Secrets Operator, and Sealed Secrets migration plan.
- `tools/helm-debug/README.md`: Helm debugging commands for value tracing and template rendering.

## Conventions

- Keep environment-specific values under deterministic paths.
- Pin upstream versions; avoid floating tags.
- Prefer small, auditable PRs for infrastructure changes.
- Treat this repository as the single source of truth for platform desired state.
