# Environment Semantics Plan

Status: Phase 1 complete; Phase 2 repo rename prepared in `gitops`

Related issues:

- `gitops#54` Document accepted and destructive Vault lifecycle boundaries for the current environment
- `gitops#55` Rename the current environment and introduce a true local sandbox

## Summary

The current GitOps environment is still named `sandbox`, but the cluster it drives is now clearly a long-lived on-prem environment with persistent shared state.

That mismatch has already caused operational confusion:

- stateful services were evaluated against sandbox assumptions
- destructive churn was easier to rationalize than it should have been
- hostnames and Flux object names now imply disposability that the environment does not actually have

The platform should treat the current cluster as `on-prem` in intent and eventually in naming.

At the same time, the platform still needs a true disposable sandbox for fast validation work. That sandbox should be local, kind-backed, and intentionally narrower in scope than the current on-prem environment.

## Current State

Before the control-plane rename, the repository used `sandbox` as the active environment label across several surfaces:

- cluster entrypoint path: `clusters/sandbox/`
- Flux `Kustomization` names:
  - `sandbox-platform-core`
  - `sandbox-bigbang`
  - `sandbox-platform-runtime`
- public and operator-facing hostnames such as:
  - `mia-sandbox.zavestudios.com`
  - `mia-canary-sandbox.zavestudios.com`
  - `grafana-sandbox.zavestudios.com`
  - `argocd-sandbox.zavestudios.com` in platform docs
- operator docs and commands that still bootstrap or apply `clusters/sandbox`

Operationally, however, the environment behaves like:

- long-lived on-prem infrastructure
- stateful platform hosting
- non-disposable recovery surface

## Target Model

The platform should move toward this split:

### 1. Current cluster becomes `on-prem`

This environment is the persistent home-lab/on-prem control plane.

Expected properties:

- long-lived
- stateful
- GitOps-managed
- recovery-sensitive
- acceptable place for shared platform services such as Vault

### 2. `sandbox` becomes a real disposable environment

This environment should be a local, kind-backed validation surface used for fast experimentation.

Expected properties:

- disposable by design
- local to an operator workstation or laptop
- narrower package set than the on-prem environment
- used for early GitOps and workload validation, not long-lived shared state

## Scope

This issue should not try to do every rename and local-environment implementation step in one PR.

Instead, it should produce a staged sequence:

1. Document the semantic split and migration sequence.
2. Rename the current persistent environment from `sandbox` to `on-prem` in `gitops`.
3. Update docs and operator commands that still describe the current cluster as a sandbox.
4. Introduce a separate local sandbox shape, most likely under a distinct environment entrypoint instead of overloading the current cluster path.

## Recommended Sequence

### Phase 1: Semantics and Planning

- document the environment split
- inventory all `sandbox` references that are implementation-significant
- decide the persistent environment name: `on-prem`
- decide whether external hostnames must rename immediately or can carry compatibility debt temporarily

### Phase 2: Rename the Current Persistent Environment in `gitops`

Expected `gitops` changes:

- rename `clusters/sandbox/` to `clusters/on-prem/`
- rename Flux `Kustomization` object names from `sandbox-*` to `on-prem-*`
- update README bootstrap/apply examples
- update repo-local references that still point to `clusters/sandbox`

Manual impact to plan carefully:

- Flux bootstrap path or reconciliation entrypoint may need manual adjustment
- existing in-cluster Flux objects may need a controlled transition rather than an in-place path move
- Argo and ingress references should be checked for implicit `sandbox` coupling

### Phase 3: Hostname and UX Cleanup

Decide whether to rename operator and tenant-facing hosts such as:

- `mia-sandbox.zavestudios.com`
- `mia-canary-sandbox.zavestudios.com`
- `grafana-sandbox.zavestudios.com`
- `argocd-sandbox.zavestudios.com`

Recommendation:

- rename infrastructure and operator-facing identifiers promptly
- allow application hostnames to follow in a separate, explicit change if needed to reduce blast radius

### Phase 4: Introduce the True Local Sandbox

The local sandbox should be deliberately narrower than the on-prem environment.

Starting point:

- kind-backed cluster
- Flux bootstrap path dedicated to the local sandbox
- minimal platform slice needed for early validation
- no expectation of persistent shared-state services

Questions to answer before implementation:

- which packages are required for useful local validation
- whether Big Bang belongs in the local sandbox at all
- how much tenant workload validation must work locally before promotion to on-prem

## Inventory of Known `sandbox` References

Implementation-significant references identified during planning included:

- `clusters/sandbox/`
- `README.md`
- `bigbang/configmap-backup.yaml`
- `bigbang/values.yaml`
- `tenants/mia/ingress.yaml`
- `tenants/mia/canary-ingress.yaml`

Documentation-only references currently include:

- `docs/mia-probe-hardening-plan.md`
- `docs/canary-rollout-pattern.md`
- `docs/image-registry-mappings.md`
- `docs/tenant-app-deployment-plan.md`
- `platform-docs/_platform/GITOPS_MODEL.md`
- `platform-docs/_platform/CONTRACT_VALIDATION.md`

This inventory should be refreshed again before hostname cleanup and local sandbox implementation.

## Non-Goals

This issue does not need to:

- re-platform the current environment
- re-open the Vault migration decision
- define the final AWS production environment model

It only needs to make the current environment semantics honest and prepare a true disposable sandbox path.

## Exit Criteria

This issue is complete when:

- the current persistent environment has a concrete rename plan
- the `gitops` implementation surface for that rename is inventoried
- a separate local sandbox approach is defined clearly enough to implement in follow-on work
- operator documentation no longer treats the current long-lived cluster as a disposable sandbox
