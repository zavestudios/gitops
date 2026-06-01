# `on-prem-bigbang` Split Proposal

**Date:** 2026-06-01

**Purpose:** Define the first target-state proposal for decomposing
`on-prem-bigbang` so `gitops#240` can reduce control-plane blast radius without
guessing at package boundaries.

**Owning issue:** `zavestudios/gitops#240`

## Why This Unit Goes First

Current evidence already established:

- `on-prem-bigbang` is the largest top-level failure domain in the `on-prem`
  graph
- it is the only current top-level `wait: true` setting that is clearly
  justified by present evidence
- a schema/config problem in this unit can block all downstream runtime and
  services work

The immediate implication is that the next control-plane refactor should not
start by removing its gate. It should start by shrinking the unit behind the
gate.

## Current Structural Constraint

Today `on-prem-bigbang` is one Flux `Kustomization` over one local package path:

- `bigbang/gitrepository.yaml`
- `bigbang/helmrelease.yaml`
- `bigbang/values.yaml`
- `bigbang/kustomization.yaml`

That path creates one `GitRepository`, one `HelmRelease`, and one generated
ConfigMap values blob.

This means the current blast radius is not just conceptual. It is enforced by
the concrete structure:

1. one Big Bang chart source
2. one Helm reconciliation unit
3. one values payload covering policy, mesh, identity, app-delivery, and
   observability concerns

Real decomposition therefore requires multiple package-scoped `HelmRelease`
objects with focused values blobs. It cannot be achieved by documentation or
file reordering alone.

## Current Package Families

Top-level package families in `bigbang/values.yaml`:

- policy:
  - `kyverno`
  - `kyvernoReporter`
  - `kyvernoPolicies`
- mesh and ingress:
  - `istioCRDs`
  - `istiod`
  - `istioGateway`
  - `kiali`
- secrets and identity:
  - `addons.externalSecrets`
  - `addons.vault`
  - `addons.keycloak`
- app-delivery:
  - `addons.argocd`
- observability:
  - `monitoring`
  - `grafana`
  - `tempo`
  - `alloy`
  - `loki`

These families do not have identical churn, prerequisites, or failure
characteristics. Treating them as one reconciliation unit is the root design
problem.

## First Target-State Proposal

Create a shared source unit plus three package-scoped Big Bang release units.

### Shared Source Unit

`on-prem-bigbang-source`

Scope:

- `namespace.yaml`
- `gitrepository.yaml`
- any shared Kustomize config needed for the values generators

Reasoning:

- the Big Bang chart source should be a reusable upstream input, not the same
  object that carries every package family behind one gate

### Release Unit 1

`on-prem-bigbang-foundation`

Scope:

- `istioCRDs`
- `istiod`
- `istioGateway`
- `addons.externalSecrets`
- `addons.vault`
- `addons.keycloak`
- `addons.argocd`

Reasoning:

- these packages establish the foundational mesh, secret, identity, and
  app-delivery substrate that other units are likely to assume
- this remains a meaningful gate, but it is much narrower than the current
  all-in-one Big Bang unit

Dependencies:

- depends on `on-prem-platform-core`
- depends on `on-prem-keycloak-secrets`
- depends on `on-prem-bigbang-source`

### Release Unit 2

`on-prem-bigbang-policy`

Scope:

- `kyverno`
- `kyvernoReporter`
- `kyvernoPolicies`

Reasoning:

- policy is a coherent family with distinct failure behavior
- a Kyverno image, webhook, or policy regression should not also block
  observability rollout

Dependencies:

- depends on `on-prem-bigbang-source`
- may depend on `on-prem-bigbang-foundation` if the current package behavior
  truly requires mesh or secret substrate first; that dependency should be
  proved, not assumed

### Release Unit 3

`on-prem-bigbang-observability`

Scope:

- `monitoring`
- `grafana`
- `tempo`
- `alloy`
- `loki`

Reasoning:

- observability has already been an active change surface and incident source
- it is operationally coherent
- it is the most obvious first place to win back partial progress: an
  observability schema problem should not block Vault, Keycloak, or ArgoCD

Dependencies:

- depends on `on-prem-bigbang-source`
- depends on `on-prem-bigbang-foundation` for mesh/ingress substrate

## Proposed Top-Level Graph

```text
on-prem-platform-core
├── on-prem-keycloak-secrets
├── on-prem-bigbang-source
└── on-prem-bigbang-foundation
    ├── on-prem-bigbang-policy
    └── on-prem-bigbang-observability
```

Then, in a follow-on step, `platform-runtime` should stop depending on one
monolithic Big Bang unit and instead depend on the specific upstream substrate
it actually needs.

## Why This Proposal Is the Right First Cut

1. It reduces the failure domain without exploding the graph into too many
   first-pass units.
2. It isolates the most active and incident-prone package family:
   observability.
3. It separates policy from observability, which gives cleaner failure signals
   and less collateral damage.
4. It keeps mesh, identity, secrets, and app-delivery together initially,
   which limits the number of dependency questions we must answer in the first
   refactor.
5. It respects the current evidence that some Big Bang health gate is still
   warranted, while shrinking the breadth of what that gate protects.

## Explicit Non-Goals for the First Pass

- do not try to solve `platform-runtime` decomposition in the same PR
- do not remove `wait: true` from every top-level unit at once
- do not split Big Bang into package-per-package releases immediately

The first pass should be about restoring control, not maximizing theoretical
purity.

## Follow-On Questions

1. Should `kiali` stay with mesh/foundation or move into observability after the
   first split?
2. Does `addons.argocd` belong in foundation, or should app-delivery become its
   own later Big Bang family?
3. Which current `platform/runtime` resources should be re-grouped once Big Bang
   observability and policy are split?
4. Which of the new top-level release units should retain `wait: true`, and
   which should move to apply ordering only?

## Suggested Next Step

Use this proposal to drive the first implementation design in `gitops#240`:

1. choose the exact release boundaries for:
   - `on-prem-bigbang-foundation`
   - `on-prem-bigbang-policy`
   - `on-prem-bigbang-observability`
2. decide whether the first implementation should introduce the shared source
   unit and values files without changing dependencies yet, or perform the full
   graph change in one step
