# Big Bang Split PR1 Plan

**Date:** 2026-06-01

**Purpose:** Define the first implementation PR for the `on-prem-bigbang`
decomposition as a structure-only change set with inactive manifests.

**Owning issue:** `zavestudios/gitops#240`

## PR1 Goal

Create the new file tree and package-scoped manifests needed for the Big Bang
split without activating any new reconciliation units yet.

The point of PR1 is reviewability, not rollout.

## What PR1 Should Include

### New Package Paths

Create:

- `bigbang/source/`
- `bigbang/foundation/`
- `bigbang/policy/`
- `bigbang/observability/`

### New Files in `bigbang/source/`

Create:

- `kustomization.yaml`
- `namespace.yaml`
- `gitrepository.yaml`

Notes:

- these should be copied or derived from the current monolithic `bigbang/`
  source material
- PR1 should not yet remove the existing source files from the monolithic path

### New Files in `bigbang/foundation/`

Create:

- `kustomization.yaml`
- `kustomizeconfig.yaml`
- `helmrelease.yaml`
- `values-foundation.yaml`

PR1 objective:

- isolate only the foundation package families
- define unique release and generated values names

### New Files in `bigbang/policy/`

Create:

- `kustomization.yaml`
- `kustomizeconfig.yaml`
- `helmrelease.yaml`
- `values-policy.yaml`

PR1 objective:

- isolate only the policy package families
- no observability or foundation package settings in this values file

### New Files in `bigbang/observability/`

Create:

- `kustomization.yaml`
- `kustomizeconfig.yaml`
- `helmrelease.yaml`
- `values-observability.yaml`

PR1 objective:

- isolate only the observability package families
- no policy or foundation package settings in this values file

### New Top-Level Flux Files

Create under `clusters/on-prem/`:

- `bigbang-source-kustomization.yaml`
- `bigbang-foundation-kustomization.yaml`
- `bigbang-policy-kustomization.yaml`
- `bigbang-observability-kustomization.yaml`

Important:

- PR1 should not yet add these files to `clusters/on-prem/kustomization.yaml`
- they exist in the repo for review, but remain inactive

## What PR1 Must Not Include

Do not:

- edit `clusters/on-prem/kustomization.yaml`
- remove `clusters/on-prem/bigbang-kustomization.yaml`
- remove the current monolithic `bigbang/helmrelease.yaml`
- remove the current monolithic `bigbang/values.yaml`
- change `platform-runtime` dependencies
- activate any new `dependsOn` edges in the live top-level graph

PR1 is intentionally non-operative.

## Why Inactive Manifests First

This sequence buys three things:

1. structural review before control-plane activation
2. package-boundary review before overlapping ownership becomes live
3. easier diff review for values extraction mistakes

If the new units are activated in the same PR that introduces them, reviewers
must reason about structure, values scope, ownership overlap, and rollout all at
once. That is unnecessary risk.

## Required Naming Rules in PR1

Each new release family should already use its final unique names.

Expected pattern:

- Helm releases:
  - `bigbang-foundation`
  - `bigbang-policy`
  - `bigbang-observability`
- generated values ConfigMaps:
  - `bigbang-foundation-values`
  - `bigbang-policy-values`
  - `bigbang-observability-values`
- Flux `Kustomization` names:
  - `on-prem-bigbang-source`
  - `on-prem-bigbang-foundation`
  - `on-prem-bigbang-policy`
  - `on-prem-bigbang-observability`

Do not use temporary names that will need a second rename PR later.

## Required Review Checks for PR1

1. The new top-level Flux files are not referenced by
   `clusters/on-prem/kustomization.yaml`.
2. Each new values file contains only its assigned package families.
3. Each new `HelmRelease` has a unique release name and ConfigMap source name.
4. The current monolithic Big Bang manifests remain intact.
5. No active graph dependency changes are introduced.

## Expected Follow-On PRs

### PR2

Activate:

- `on-prem-bigbang-source`

Only if the source path is independently reviewable and low-risk.

### PR3

Activate:

- `on-prem-bigbang-foundation`

This PR must include the handoff plan for overlapping ownership with the
monolithic `on-prem-bigbang`.

### PR4

Activate:

- `on-prem-bigbang-policy`
- `on-prem-bigbang-observability`

Then retire:

- `on-prem-bigbang`

### PR5

Revisit:

- `platform-runtime` dependencies
- top-level `wait: true` posture after the split is live

## Open Design Questions Before PR1 Is Authored

1. Should `kiali` stay with foundation in PR1, or be modeled as observability
   from the start?
2. Should `addons.argocd` stay in foundation for the first pass, or be treated
   as a separate later family?
3. Are there any shared top-level values that must be duplicated across the
   package-scoped values files?
4. Which comments from the current monolithic `values.yaml` are essential enough
   to preserve verbatim in the new split files?

## Suggested Next Step

Use this plan to author the first actual implementation PR against `gitops`:

1. create the new directories and inactive manifests
2. keep all active cluster entrypoints unchanged
3. review the resulting values split before discussing activation
