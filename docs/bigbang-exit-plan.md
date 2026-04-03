# Big Bang Exit Plan

Status: open

Related issues:

- create epic: Exit Big Bang in favor of directly owned GitOps primitives
- follow-up issue: Stabilize current Big Bang deployment and bound remaining policy noise

## Summary

The current on-prem platform is still deployable through Big Bang, but repeated recovery work has shown that Big Bang is now a control-plane abstraction tax rather than a simplifier.

Recent failures were not caused by Kubernetes fundamentals being unknowable. They were caused by an extra ownership layer:

- umbrella-chart rendering failures blocked unrelated package progress
- package-specific value paths were hard to discover and verify
- post-render customizations were brittle and sometimes not accepted by the parent chart
- the source of truth for a live object often had to be traced through parent values, generated child `HelmRelease` objects, and controller-owned state

The short-term goal is still to stabilize the current environment.

The medium-term goal is to remove Big Bang as the umbrella control plane and replace it with directly owned Flux-native resources in this repository.

## Why This Exists

This plan exists to separate two concerns that should not be mixed:

1. Keep the current platform operational now.
2. Remove the architecture that keeps making routine changes more expensive than they should be.

This document is an execution epic for `gitops`, not a platform-doctrine change.

## Problem Statement

Big Bang currently introduces the following costs in this environment:

- parent release failures can block otherwise healthy child package lifecycles
- package behavior is sometimes controlled by undocumented or chart-specific value interfaces
- durable ownership of rendered manifests is blurred between:
  - `gitops/bigbang/values.yaml`
  - generated child `HelmRelease` objects
  - package charts and their own internal defaults
- policy hardening often requires post-render patches instead of first-class manifests
- cluster debugging becomes slower because declared truth and rendered truth are too far apart

These are not theoretical concerns. They have already appeared in:

- Keycloak recovery and image override work
- Kyverno warning remediation
- `kyverno-reporter` umbrella render failures
- platform hardening work that should have been straightforward direct manifest changes

## Target State

The target operating model is:

- Flux remains the platform GitOps authority
- this repository owns package installation directly
- each platform capability is represented by a small, explicit, directly-debuggable surface
- package upgrades are isolated from each other
- policy hardening is expressed in first-class manifests or package-native values, not hidden behind umbrella indirection

In practice, that means replacing the current Big Bang umbrella ownership with some combination of:

- direct `HelmRelease` objects per package
- direct `Kustomization` / raw manifest ownership for simple platform resources
- explicit namespace, ServiceAccount, policy, and ingress ownership in `platform/`

## Scope

In scope:

- planning the Big Bang exit sequence
- defining the package migration order
- moving platform packages from umbrella ownership to direct Flux ownership
- preserving current package versions initially to reduce migration risk
- reducing render indirection and tightening ownership boundaries

Out of scope for the first migration wave:

- changing platform doctrine in `platform-docs`
- redesigning workload contract semantics
- replacing Flux
- making broad version upgrades at the same time as ownership migration
- introducing a disposable local sandbox in the same change set

## Principles

### 1. Stabilize before peel-out

Do not start removing Big Bang while the current environment is still in a broken or ambiguous state.

### 2. Preserve versions first

The first exit wave should preserve current package versions where possible.
Migration and upgrade should be separate changes.

### 3. One ownership boundary at a time

Each package should move from:

- Big Bang umbrella ownership

to:

- direct Flux `HelmRelease` ownership

without changing multiple adjacent control planes at once.

### 4. Prefer native package inputs over post-render patches

If a package supports a native value for a requirement, use that first.
Post-render patching should remain the fallback, not the default architecture.

### 5. Keep cluster-critical packages isolated

Packages that install CRDs, admission controllers, or shared ingress paths should be migrated in deliberate phases, not bulk-moved.

## Current Candidate Package Set

Likely migration candidates from the current Big Bang footprint:

- `kyverno`
- `kyverno-policies`
- `monitoring`
- `grafana`
- `kiali`
- `istiod`
- `istio-gateway` / `public-ingressgateway`
- `external-secrets`
- `vault`
- `keycloak`
- `tempo`
- `alloy`
- `argocd`
- `loki`

Exact package inventory should be refreshed from the live cluster before execution begins.

## Recommended Phases

### Phase 0: Stabilization Gate

Exit work does not begin until all of the following are true:

- `HelmRelease/bigbang` is healthy
- `Kustomization/on-prem-bigbang` is healthy
- current policy warning volume is understood and bounded
- current manual recovery steps are documented

### Phase 1: Inventory and Ownership Mapping

Produce a package inventory with these fields:

- package name
- current namespace
- current owner (`bigbang` umbrella, direct manifest, or mixed)
- upstream chart source
- installed version
- CRD ownership
- ingress / DNS dependencies
- storage dependencies
- policy exceptions or hardening requirements

Output of this phase should make it obvious which packages can move first without destabilizing the cluster.

### Phase 2: Extract Low-Risk Packages

Start with packages that are valuable to own directly but have limited blast radius.

Initial candidates:

- `keycloak`
- `external-secrets`
- `kiali`
- `tempo`
- `alloy`

Exit condition:

- each package runs from a directly owned `HelmRelease`
- Big Bang no longer renders that child package
- live behavior matches pre-migration state

### Phase 3: Extract Policy and Observability Components

Migrate the packages that have already required the most policy-hardening attention.

Candidates:

- `kyverno`
- `kyverno-policies`
- `monitoring`
- `grafana`
- `loki`

This phase should explicitly capture:

- ServiceAccount ownership
- `automountServiceAccountToken` behavior
- required labels
- CRD sequencing

### Phase 4: Extract Traffic and Identity Components

Move the packages with shared ingress and identity blast radius:

- `istiod`
- `istio-gateway`
- `vault`
- `keycloak` if not already migrated in Phase 2

These should be split into small changes with explicit rollback paths.

### Phase 5: Remove Big Bang Umbrella

Only after all required child packages are directly owned:

- remove umbrella-specific resources under `bigbang/`
- replace them with direct package directories and Flux objects
- update cluster entrypoints under `clusters/on-prem/`
- remove obsolete values-generation and umbrella reconciliation objects

### Phase 6: Post-Exit Cleanup

- remove Big Bang-specific docs and incident debt
- convert temporary patches into package-native configuration where possible
- update README and operational runbooks to reflect direct ownership

## Proposed Repository Shape After Exit

One reasonable target layout:

```text
bigbang/                     # temporary during migration only
platform/
  core/
  runtime/
  security/
packages/
  kyverno/
  kyverno-policies/
  monitoring/
  grafana/
  kiali/
  istiod/
  istio-gateway/
  external-secrets/
  vault/
  keycloak/
  tempo/
  alloy/
  loki/
  argocd/
clusters/
  on-prem/
```

This is illustrative, not final.
The main requirement is that package ownership is direct and legible.

## Risks

Primary risks:

- CRD ordering mistakes during package extraction
- duplicate ownership between Big Bang and direct `HelmRelease` resources
- ingress or DNS regressions during traffic-component migration
- hidden value defaults lost during direct chart adoption
- policy churn during the transition period

Mitigations:

- preserve versions initially
- move one package at a time
- keep rollback path as “return ownership to Big Bang” until each package is proven stable
- validate declared truth, rendered truth, controller truth, and live runtime truth for each package move

## Execution Checklist

- [ ] Confirm current Big Bang environment is stable
- [ ] Produce live package inventory
- [ ] Choose first extraction wave
- [ ] Document package-by-package rollback path
- [ ] Migrate first package to direct Flux ownership
- [ ] Validate health, drift, policy posture, and user-visible behavior
- [ ] Repeat until umbrella has no required children left
- [ ] Remove Big Bang umbrella resources

## Exit Criteria

This epic is complete when:

- no required platform package depends on the Big Bang umbrella chart
- package ownership is direct, explicit, and individually debuggable
- Flux reconciliation no longer depends on parent umbrella rendering to manage child package lifecycle
- package hardening can be expressed in native values or directly owned manifests
- `gitops` documentation reflects the post-Big-Bang operating model

## Suggested Follow-On Issues

Create one issue per migration wave:

- inventory and ownership map
- low-risk package extraction
- policy and observability extraction
- traffic and identity extraction
- Big Bang removal and repo cleanup

Do not track the entire exit in one unbounded issue after this epic is created.
