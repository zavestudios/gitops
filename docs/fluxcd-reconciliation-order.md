# FluxCD Reconciliation Order

## Overview

FluxCD reconciles the gitops repository in a dependency-ordered sequence. Each Kustomization waits for its dependencies before applying resources.

## Reconciliation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                flux-system (bootstrap)                       │
│  Created by: flux bootstrap                                  │
│  Source: GitRepository flux-system                           │
│  Path: clusters/on-prem/                                     │
│  Defines: Kustomization CRDs for platform layers             │
└────────────┬────────────────────────────────────────────────┘
             │
    ┌────────┴────────┐
    ▼                 ▼
┌────────────┐   ┌───────────────────────────┐
│ platform-  │   │ keycloak-secrets          │
│ core       │   │ (depends on platform-core)│
│            │   └──────────┬────────────────┘
│ • namespaces              │
│ • service accounts        │
│ • sealed-secrets          │
│ • cloudflared             │
└────────┬───┘              │
         │                  │
         └──────────┬───────┘
                    ▼
            ┌───────────────┐
            │  bigbang      │
            │               │
            │ • istio       │
            │ • monitoring  │
            │ • keycloak    │
            │ • other BB    │
            └──────┬────────┘
                   ▼
            ┌──────────────┐
            │ platform-    │
            │ runtime      │
            │              │
            │ • vault      │
            │ • kyverno    │
            │ • argocd     │
            └──────────────┘
```

## Kustomization Details

### 0. flux-system (bootstrap)
**FluxCD Name:** `flux-system`
**Path:** `clusters/on-prem/`
**Dependencies:** None (created by flux bootstrap)
**Purpose:** Root kustomization that defines all other Kustomization resources.

This is installed during cluster bootstrap with `flux bootstrap` and manages the entry point. It reconciles the cluster configuration directory, which contains YAML definitions for the other Kustomizations.

---

### 1. platform-core
**FluxCD Name:** `on-prem-platform-core`
**Path:** `./platform/core`
**Dependencies:** None (first application-layer kustomization)
**Wait:** No
**Interval:** 10m

**Owns:**
- `platform/namespaces/` - Core namespaces (platform, istio-system, etc.)
- `platform/namespaces/default-serviceaccounts.yaml` - Default service accounts
- `platform/sealed-secrets/` - Sealed Secrets controller
- `platform/cloudflare/` - Cloudflared tunnel (credentials from Vault)

**Purpose:** Bootstrap essential infrastructure that other components depend on
without blocking the graph on child health. This prevents the cloudflared
ExternalSecret from deadlocking the controller update path.

---

### 2. keycloak-secrets
**FluxCD Name:** `on-prem-keycloak-secrets`
**Path:** `./platform/keycloak`
**Dependencies:** `on-prem-platform-core`
**Wait:** No
**Interval:** 10m

**Owns:**
- `platform/keycloak/namespace.yaml` - Keycloak namespace
- `platform/keycloak/*.external-secret.yaml` - ExternalSecrets for Keycloak credentials

**Purpose:** Ensure Keycloak secret resources are applied before BigBang
deploys Keycloak. Dependency ordering stays explicit via `dependsOn`, but
child health does not block the graph here.

---

### 3. bigbang
**FluxCD Name:** `on-prem-bigbang`
**Path:** `./bigbang`
**Dependencies:**
- `on-prem-platform-core`
- `on-prem-keycloak-secrets`

**Wait:** Yes
**Interval:** 10m
**Timeout:** 20m

**Owns:**
- BigBang Helm release
- Istio service mesh
- Monitoring stack (Prometheus, Grafana, etc.)
- Keycloak deployment
- Other Big Bang components

**Purpose:** Deploy the Big Bang platform distribution with all its components.

---

### 4. platform-runtime
**FluxCD Name:** `on-prem-platform-runtime`
**Path:** `./platform/runtime`
**Dependencies:** `on-prem-bigbang`
**Wait:** Yes
**Interval:** 10m
**Timeout:** 20m

**Owns:**
- `platform/vault/` - HashiCorp Vault deployment and configuration
- `platform/policies/kyverno/` - Kyverno policies for governance
- `platform/argocd/` - ArgoCD installation and tenant Applications

**Purpose:** Deploy platform services that depend on Istio, monitoring, and other BigBang components.

---

## Reconciliation Behavior

### Wait Semantics
Health-gated kustomizations have `wait: true`, meaning FluxCD will:
1. Apply all resources
2. Wait for all resources to become Ready
3. Only then mark the kustomization as Ready
4. Allow dependent kustomizations to proceed

### Dependency Resolution
- FluxCD evaluates `dependsOn` before reconciling
- If any dependency is not Ready, reconciliation is skipped
- Circular dependencies are not allowed

### Prune Behavior
All kustomizations have `prune: true`:
- Resources removed from Git are deleted from cluster
- Enables full GitOps: Git is source of truth

## Tenant Workloads

Tenant applications (panchito, oracle, mia, rigoberta, etc.) are managed by **ArgoCD**, not FluxCD.

**Reconciliation flow for tenants:**
```
FluxCD reconciles platform-runtime
  └─> Deploys ArgoCD
      └─> ArgoCD deploys Applications from platform/argocd/applications/
          └─> Each Application references tenant source repo
              └─> ArgoCD deploys tenant workload
```

**Tenant kustomizations in gitops repo:**
- `tenants/panchito/` - Application manifests (referenced by ArgoCD)
- `tenants/oracle/` - Application manifests (referenced by ArgoCD)
- etc.

These are **not** managed by FluxCD kustomizations directly - they're referenced by ArgoCD Application resources.

## Troubleshooting

### Check reconciliation status
```bash
flux get kustomizations -n flux-system
```

### Check specific kustomization
```bash
flux get kustomization on-prem-platform-core -n flux-system
flux logs -n flux-system --kind=Kustomization --name=on-prem-platform-core
```

### Force reconciliation
```bash
flux reconcile kustomization on-prem-platform-core -n flux-system
```

### Dependency tree
```bash
flux tree kustomization on-prem-platform-runtime -n flux-system
```

## Cloudflare Tunnel Position

**Cloudflared is in platform-core** (not platform-runtime) because:
1. It's network infrastructure, not an application service
2. Requires early deployment for external connectivity
3. Depends only on namespace and External Secrets Operator
4. BigBang and tenants may need it for health checks or webhooks

When the cloudflared deployment is updated (new tunnel ID, config changes):
1. FluxCD detects change in `platform/cloudflare/deployment.yaml`
2. Reconciles `on-prem-platform-core` kustomization
3. Applies updated deployment
4. Pods restart with new configuration
5. Vault credentials are read via ExternalSecret

## Related Documentation

- FluxCD Kustomization API: https://fluxcd.io/docs/components/kustomize/kustomization/
- Dependency ordering: https://fluxcd.io/docs/components/kustomize/kustomization/#dependencies
