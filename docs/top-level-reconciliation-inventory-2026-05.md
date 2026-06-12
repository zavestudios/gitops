# Top-Level Reconciliation Inventory

**Date:** 2026-05-27

**Purpose:** Inventory the current top-level Flux reconciliation graph for the
`on-prem` environment so `gitops#240` can discuss `wait: true`, dependency
gating, and blast radius from concrete evidence.

**Owning issue:** `zavestudios/gitops#240`

## Current Entry Point

Cluster entrypoint:

- `clusters/on-prem/kustomization.yaml`

Top-level reconciliation units:

1. `on-prem-platform-core`
2. `on-prem-keycloak-secrets`
3. `on-prem-bigbang`
4. `on-prem-platform-runtime`
5. `on-prem-platform-services`

## Graph Summary

```text
on-prem-platform-core
├── on-prem-keycloak-secrets
└── on-prem-bigbang
    └── on-prem-platform-runtime
        └── on-prem-platform-services
```

Structural observations:

- four of five top-level units use `wait: true`
- `on-prem-bigbang` is the central health gate for downstream runtime and
  services work
- `on-prem-platform-services` is the only top-level unit without `wait: true`
- the graph currently optimizes for ordered convergence, but it does so by
  concentrating failure blast radius in `on-prem-bigbang`

## Inventory Table

| Kustomization | Path | Depends On | Interval | Timeout | `wait: true` | Current Scope | Blast Radius if Stalled |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `on-prem-platform-core` | `./platform/core` | none | `10m` | default | No | namespaces, default serviceaccounts, sealed-secrets, cloudflare | no longer blocks downstream units on child health; still supplies foundational manifests |
| `on-prem-keycloak-secrets` | `./platform/keycloak` | `on-prem-platform-core` | `10m` | default | Yes | keycloak namespace, headless service, ExternalSecrets | blocks `bigbang` because Big Bang expects Keycloak secrets first |
| `on-prem-bigbang` | `./bigbang` | `on-prem-platform-core`, `on-prem-keycloak-secrets` | `10m` | `20m` | Yes | Big Bang GitRepository, HelmRelease, generated values, shared platform stack | blocks all downstream runtime and services work |
| `on-prem-platform-runtime` | `./platform/runtime` | `on-prem-bigbang` | `10m` | `20m` | Yes | Alloy receiver, Alloy hook support, Vault, Kyverno, ArgoCD platform resources | blocks `platform-services`; also delays shared runtime remediation outside Big Bang |
| `on-prem-platform-services` | `./platform/services` | `on-prem-platform-runtime` | `2m` | `25m` | No | Airflow platform service | isolated leaf tier; currently blocked entirely by upstream runtime gate |

## Unit Notes

### `on-prem-platform-core`

Evidence:

- file count under `platform/core/`: `1`
- resources fan out to:
  - `../namespaces/namespaces.yaml`
  - `../namespaces/default-serviceaccounts.yaml`
  - `../sealed-secrets/`
  - `../cloudflare/`

Assessment:

- the scope is foundational but relatively small
- `wait: true` here may be load-bearing if downstream units genuinely require
  these resources to be healthy before apply, but the exact requirement should
  be checked instead of assumed

Open question:

- does this unit need health gating, or only apply ordering?

### `on-prem-keycloak-secrets`

Evidence:

- file count under `platform/keycloak/`: `4`
- current path manages namespace, headless service, and ExternalSecrets only

Assessment:

- this is a narrow prerequisite unit
- it exists only to ensure Keycloak-related secrets and service wiring are
  present before Big Bang
- the scope is small enough that a stall here is legible, but it still blocks
  `on-prem-bigbang`

Open question:

- should this remain a separate unit, or should the dependency be modeled
  differently so Keycloak secret readiness does not hold the entire Big Bang
  tier hostage?

### `on-prem-bigbang`

Evidence:

- file count under `bigbang/`: `12`
- owns:
  - `gitrepository.yaml`
  - `helmrelease.yaml`
  - `values.yaml`
  - `releases/3.17.0`
  - support config files and namespace
- `wait: true`
- `timeout: 20m`
- proven incident: corrected generated values did not self-heal until
  `flux reconcile helmrelease bigbang -n bigbang --force`

Assessment:

- this is the dominant blast-radius unit in the current graph
- it is both a broad shared-platform surface and a hard health gate
- it is the first target for structural decomposition

Open questions:

- which Big Bang-managed surfaces should be split out of this unit first:
  observability, policy, identity, or another tier?
- which dependencies actually require health gating versus simple apply order?

### `on-prem-platform-runtime`

Evidence:

- file count under `platform/runtime/`: `8`
- currently includes:
  - Alloy receiver
  - Alloy hook support
  - Vault
  - Kyverno
  - ArgoCD platform resources
- `wait: true`
- `dependsOn: on-prem-bigbang`

Assessment:

- this unit is not small; it bundles several distinct platform control-plane
  surfaces
- despite being named "runtime", it includes security/policy and app-delivery
  substrate concerns
- it is a second major aggregation point behind `on-prem-bigbang`

Open question:

- should ArgoCD, Vault, Kyverno, and Alloy-related runtime glue remain in one
  top-level unit?

### `on-prem-platform-services`

Evidence:

- file count under `platform/services/`: `11`
- currently only includes Airflow
- no `wait: true`
- shortest interval in the top-level graph: `2m`

Assessment:

- this is the healthiest pattern in the current graph
- it is leaf-scoped and not itself a major blast-radius source
- its biggest problem is that upstream gates can still starve it completely

Open question:

- once upstream runtime is decomposed, should additional platform services live
  here, or should services be split by capability family?

## Immediate Findings

1. `on-prem-bigbang` is the largest single top-level failure domain.
2. `on-prem-platform-runtime` is also too broad for a single gated unit.
3. The current graph uses `wait: true` as a default posture for most top-level
   units rather than as a narrowly justified health gate.
4. A single Helm schema/config problem in `on-prem-bigbang` can block:
   - Big Bang itself
   - runtime glue and platform security surfaces
   - shared platform services
5. The graph is legible enough to audit now, but not yet shaped for graceful
   partial progress.

## First Refactor Targets

Recommended first-pass targets for `gitops#240`:

1. Audit whether `wait: true` is actually load-bearing for:
   - `on-prem-platform-core`
   - `on-prem-keycloak-secrets`
   - `on-prem-platform-runtime`

2. Define the first `on-prem-bigbang` split proposal.
   Candidate split axes:
   - observability surfaces
   - identity/auth surfaces
   - policy/security surfaces

3. Re-evaluate `platform-runtime` composition.
   Candidate split axes:
   - policy and admission
   - secrets/runtime identity
   - app-delivery substrate
   - observability runtime glue

## Suggested Next Step

Use this inventory directly in `gitops#240` to drive two follow-up artifacts:

1. a `wait: true` justification table
2. a first proposed target-state graph for top-level reconciliation units
