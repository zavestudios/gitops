# Namespace and Resource Ownership Contracts

**Date:** 2026-06-21

**Owning issue:** `zavestudios/gitops#257`

## Rule

A top-level Flux reconciliation unit may write namespaced resources only when
one of these conditions holds:

1. the same unit creates the namespace
2. the namespace is a Kubernetes built-in
3. the unit directly depends on the reconciliation unit that guarantees the
   namespace

Transitive ordering is not sufficient for cross-unit namespace writes. Direct
dependencies preserve the contract when intermediate graph edges change.

Cluster-scoped resources do not require a namespace owner, but their CRDs or
controllers must still be guaranteed by an explicit dependency when needed.

## Ownership Matrix

| Reconciliation unit | Direct namespace writes | Namespace authority | Contract |
| --- | --- | --- | --- |
| `on-prem-platform-core` | `default`, `ingress`, `kube-node-lease`, `kube-public`, `kube-system`, `platform` | self for `ingress` and `platform`; Kubernetes for built-ins | `monitoring` is also created here for package use, but no directly rendered core resource writes into it |
| `on-prem-keycloak-secrets` | `keycloak` | self | creates `keycloak` in the same path; depends on core for prerequisite controllers and secrets infrastructure |
| `on-prem-bigbang-source` | `bigbang` | self | creates `bigbang` before reconciling the source object |
| `on-prem-bigbang-foundation` | `bigbang` | `on-prem-bigbang-source` | directly depends on source; enabled child packages guarantee namespaces including `vault` and `argocd` |
| `on-prem-bigbang-policy` | `bigbang` | `on-prem-bigbang-source` | directly depends on source; enabled policy packages guarantee their package namespaces and CRDs |
| `on-prem-bigbang-observability` | `bigbang` | `on-prem-bigbang-source` | directly depends on source; enabled observability packages guarantee `alloy` and related package namespaces |
| `on-prem-platform-runtime` | `alloy`, `argocd`, `kyverno`, `platform`, `vault` | `on-prem-bigbang-observability`, `on-prem-bigbang-foundation`, `on-prem-bigbang-policy`, `on-prem-platform-core`, `on-prem-bigbang-foundation` | directly depends on every namespace authority; policy also supplies the Kyverno CRDs used by cluster policies |
| `on-prem-platform-services` | `platform` | `on-prem-platform-core` | directly depends on core for the namespace and runtime for shared capabilities |

Big Bang child resources are rendered by the upstream umbrella chart rather
than this repository's Kustomize paths. Each family release owns the namespaces
and resources produced by the packages enabled in its values file. Cross-family
ownership remains tracked separately under `zavestudios/gitops#258`.

## Audit Findings

The post-incident audit found two contracts that were correct only through
transitive graph ordering:

- `on-prem-platform-runtime` wrote `ServiceAccount/vault-reader` into
  `platform` without directly depending on `on-prem-platform-core`
- `on-prem-platform-services` reconciled Airflow resources into `platform`
  without directly depending on `on-prem-platform-core`

Both units now declare the namespace authority directly. No other directly
rendered namespace/resource mismatch remains in the active top-level graph.

The following writes are intentional exceptions, not ownership gaps:

- default ServiceAccount hardening in the Kubernetes built-in namespaces
  `default`, `kube-public`, and `kube-node-lease`
- sealed-secrets controller resources in the Kubernetes built-in namespace
  `kube-system`

## Validation

Run:

```bash
scripts/audit-namespace-ownership.sh
```

The audit renders each top-level path, verifies its namespace surface, and
checks every required direct dependency. An intentional namespace change must
update both the script contract and this matrix in the same pull request.
