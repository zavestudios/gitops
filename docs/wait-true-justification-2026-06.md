# `wait: true` Justification Table

**Date:** 2026-06-01

**Purpose:** Classify the current top-level `wait: true` settings in the
`on-prem` Flux graph so `gitops#240` can distinguish load-bearing health gates
from default gating posture.

**Owning issue:** `zavestudios/gitops#240`

## Scope

This review covers the current top-level Flux `Kustomization` objects under:

- `clusters/on-prem/platform-core-kustomization.yaml`
- `clusters/on-prem/keycloak-secrets-kustomization.yaml`
- `clusters/on-prem/bigbang-kustomization.yaml`
- `clusters/on-prem/platform-runtime-kustomization.yaml`
- `clusters/on-prem/platform-services-kustomization.yaml`

## Classification Legend

- `Required`: current downstream behavior appears to depend on child health, not
  just apply ordering
- `Provisional`: there may be a real health-gating need, but the current repo
  evidence does not prove it cleanly
- `Remove candidate`: current repo evidence favors apply ordering over strict
  health gating

## Current Table

| Kustomization | Current `wait: true` | Classification | Reasoning | Proposed action |
| --- | --- | --- | --- | --- |
| `on-prem-platform-core` | No | Resolved | Health gating here created a bootstrap deadlock: `platform-core` waited on `cloudflared-credentials`, which waited on `vault-kv`, which could not recover until the updated `external-secrets` controller came through `bigbang`. Apply ordering remains explicit via `dependsOn`; child health should not block the graph at this layer. | Keep `wait` disabled unless a specific downstream prerequisite proves it must be reintroduced. |
| `on-prem-keycloak-secrets` | No | Resolved | This unit was also health-gating on `ExternalSecret` readiness and therefore participated in the same bootstrap deadlock as `platform-core`. Big Bang only needs the secret-producing resources to exist in GitOps order; it should not wait for the current Vault/controller loop to fully settle here. | Keep `wait` disabled unless a concrete Keycloak readiness dependency is proven later. |
| `on-prem-bigbang` | Yes | Required | This is a broad shared-platform tier centered on a `HelmRelease`, and the recent incident showed that downstream runtime and services behavior is materially coupled to whether this unit reaches a good state. Removing the gate before decomposition would trade a legible blocker for less predictable downstream failure. | Keep `wait: true` in place for now; make this the first structural split target. |
| `on-prem-platform-runtime` | Yes | Remove candidate | This unit currently bundles Alloy receiver/hook support, Vault, Kyverno, and ArgoCD platform resources. That scope is too broad for one hard health gate, and the repo evidence does not show that all downstream services need the entire bundle healthy before they can apply. The current gate likely amplifies blast radius more than it protects correctness. | First preference: split the unit. Short of that, test whether the gate can be relaxed to apply ordering only. |
| `on-prem-platform-services` | No | N/A | This leaf tier already avoids `wait: true` and is the healthiest pattern in the current graph. | Preserve this default unless a specific service family proves a real health-gating need. |

## Immediate Conclusions

1. `on-prem-bigbang` is the only current top-level unit whose `wait: true`
   setting is clearly justified by present evidence.
2. `on-prem-platform-core` no longer health-gates the graph; the bootstrap
   deadlock it created is now removed.
3. `on-prem-keycloak-secrets` no longer health-gates the graph for the same
   reason; apply ordering is enough at this layer.
4. `on-prem-platform-runtime` is the strongest `wait: true` removal candidate in
   the current graph, though splitting it is preferable to simply dropping the
   gate blindly.
5. The current graph uses health gating as a default control-plane posture more
   often than the repo evidence supports.

## Follow-Up Questions for `gitops#240`

1. What exact runtime property is each gated unit protecting:
   - resource existence
   - controller reconciliation
   - secret materialization
   - application readiness
2. Which downstream units truly fail if upstream health is absent, versus merely
   needing upstream manifests applied first?
3. Should `on-prem-platform-runtime` be decomposed before any `wait: true`
   change, so that gating decisions are made on smaller, coherent units?

## Suggested Next Step

Use this table to drive the next artifact in `gitops#240`:

1. a target-state proposal for splitting `on-prem-bigbang`
2. a second-pass review of whether `on-prem-platform-runtime` should be split by
   policy, secrets/identity, observability, or app-delivery substrate
