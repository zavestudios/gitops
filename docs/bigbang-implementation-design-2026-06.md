# `on-prem-bigbang` Implementation Design

**Date:** 2026-06-01

**Purpose:** Translate the merged `on-prem-bigbang` split proposal into a
concrete implementation design with explicit file moves, new Flux objects, and
an ordered rollout plan.

**Owning issue:** `zavestudios/gitops#240`

## Design Goal

Replace the current single `on-prem-bigbang` reconciliation unit:

- one top-level Flux `Kustomization`
- one local `bigbang/` package path
- one Big Bang `HelmRelease`
- one generated ConfigMap values blob

with a smaller set of package-scoped Big Bang release units that reduce blast
radius while preserving legible dependency order.

## Current Files

Current Big Bang package path:

- `bigbang/namespace.yaml`
- `bigbang/gitrepository.yaml`
- `bigbang/helmrelease.yaml`
- `bigbang/kustomization.yaml`
- `bigbang/kustomizeconfig.yaml`
- `bigbang/values.yaml`

Current top-level Flux object:

- `clusters/on-prem/bigbang-kustomization.yaml`

## Target File Layout

Introduce one shared source path and three release paths.

### Shared Source Path

`bigbang/source/`

Files:

- `namespace.yaml`
- `gitrepository.yaml`
- `kustomization.yaml`

Role:

- own the shared Big Bang namespace and chart source
- provide a stable dependency target for all package-scoped Big Bang releases

### Foundation Release Path

`bigbang/foundation/`

Files:

- `helmrelease.yaml`
- `kustomization.yaml`
- `kustomizeconfig.yaml`
- `values-foundation.yaml`

Package scope:

- `istioCRDs`
- `istiod`
- `istioGateway`
- `addons.externalSecrets`
- `addons.vault`
- `addons.keycloak`
- `addons.argocd`

### Policy Release Path

`bigbang/policy/`

Files:

- `helmrelease.yaml`
- `kustomization.yaml`
- `kustomizeconfig.yaml`
- `values-policy.yaml`

Package scope:

- `kyverno`
- `kyvernoReporter`
- `kyvernoPolicies`

### Observability Release Path

`bigbang/observability/`

Files:

- `helmrelease.yaml`
- `kustomization.yaml`
- `kustomizeconfig.yaml`
- `values-observability.yaml`

Package scope:

- `monitoring`
- `grafana`
- `tempo`
- `alloy`
- `loki`

## Target Flux Objects

Add four new top-level Flux `Kustomization` objects under `clusters/on-prem/`:

- `bigbang-source-kustomization.yaml`
- `bigbang-foundation-kustomization.yaml`
- `bigbang-policy-kustomization.yaml`
- `bigbang-observability-kustomization.yaml`

Proposed names:

- `on-prem-bigbang-source`
- `on-prem-bigbang-foundation`
- `on-prem-bigbang-policy`
- `on-prem-bigbang-observability`

Retire:

- `clusters/on-prem/bigbang-kustomization.yaml`

## Target Top-Level Graph

```text
on-prem-platform-core
├── on-prem-keycloak-secrets
├── on-prem-bigbang-source
└── on-prem-bigbang-foundation
    ├── on-prem-bigbang-policy
    └── on-prem-bigbang-observability
        └── on-prem-platform-runtime
            └── on-prem-platform-services
```

Notes:

- `platform-runtime` should depend on the narrowest upstream substrate it
  actually needs
- as an initial conservative step, it may continue to depend on
  `on-prem-bigbang-observability` until the runtime split is designed
- that dependency should be revisited immediately after the Big Bang split lands

## HelmRelease Design Rules

Each new release path should define its own:

- `HelmRelease.metadata.name`
- generated ConfigMap values name
- values file

This is required so each package family gets an independent Helm reconciliation
surface and independent failure/result history.

Example naming pattern:

- Helm releases:
  - `bigbang-foundation`
  - `bigbang-policy`
  - `bigbang-observability`
- generated values ConfigMaps:
  - `bigbang-foundation-values`
  - `bigbang-policy-values`
  - `bigbang-observability-values`

## Values Extraction Rules

The first implementation should copy only the package families explicitly owned
by each release path.

Do not:

- keep one shared `values.yaml` and try to filter it at runtime
- share one generated ConfigMap across multiple Helm releases
- carry disabled or unrelated package families into every release values file

The goal is independent package-scoped values, not the appearance of
decomposition.

## Migration Strategy

Use a staged rollout rather than a one-shot replacement.

### Stage 1: Add Source Path

Create:

- `bigbang/source/`
- `clusters/on-prem/bigbang-source-kustomization.yaml`

Do not change the current `on-prem-bigbang` unit yet.

Goal:

- establish the reusable chart source and namespace surface first

### Stage 2: Add Parallel Values Files and Release Manifests

Create:

- `bigbang/foundation/`
- `bigbang/policy/`
- `bigbang/observability/`

Prepare:

- package-scoped values files
- package-scoped `HelmRelease` manifests
- top-level Flux `Kustomization` manifests

Do not enable them in the top-level `clusters/on-prem/kustomization.yaml` entry
point yet.

Goal:

- make the implementation reviewable before it becomes active

### Stage 3: Cut Over the First Release

Recommended first cutover:

- foundation first

Why:

- observability is the main blast-radius motivation, but foundation is the
  dependency base the other Big Bang units will likely need
- getting foundation stable first gives cleaner follow-on edges for policy and
  observability

At this stage:

- activate `on-prem-bigbang-source`
- activate `on-prem-bigbang-foundation`
- keep the old monolithic `on-prem-bigbang` in place only long enough to avoid
  a broken graph during the transition

This is the most delicate stage and should be designed so there is never a
window where both old and new releases are fighting over the same package family
without an explicit handoff plan.

### Stage 4: Cut Over Policy and Observability

Activate:

- `on-prem-bigbang-policy`
- `on-prem-bigbang-observability`

Then retire:

- the old monolithic `on-prem-bigbang`

### Stage 5: Repoint Runtime Dependencies

After the Big Bang split is stable:

- re-evaluate whether `platform-runtime` should depend on
  `on-prem-bigbang-foundation`, `on-prem-bigbang-observability`, or something
  narrower

This should be its own follow-up change, not bundled into the initial split.

## Review Checklist for the First Implementation PR

1. No new Big Bang release values file contains package families owned by a
   different release.
2. Each new Helm release has a unique release name and generated ConfigMap name.
3. Top-level `dependsOn` edges are explicit and minimal.
4. No old and new release units are left targeting the same package family
   indefinitely.
5. The cutover order is documented in the PR body.
6. The PR states exactly which top-level reconciliation units are added,
   changed, and retired.

## Main Risk

The main implementation risk is not YAML mechanics. It is overlapping ownership.

If the old monolithic release and the new package-scoped release both manage the
same Big Bang package family at the same time, the control plane will become
less predictable, not more.

That means the cutover plan must be treated as part of the implementation
design, not as cleanup for later.

## Suggested Next Step

Use this design to plan the first implementation PR:

1. create the new file tree and inactive manifests
2. decide the exact cutover sequence for retiring the monolithic
   `on-prem-bigbang`
3. choose whether foundation-first is still the least-risk first activation once
   the package overlap is mapped in detail
