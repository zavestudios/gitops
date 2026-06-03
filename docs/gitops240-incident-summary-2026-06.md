# `gitops#240` Incident Summary

**Date:** 2026-06-02

**Purpose:** Record the actual causes, effective recovery actions, and remaining
cleanup debt from the `gitops#240` control-plane stabilization effort.

**Owning issue:** `zavestudios/gitops#240`

## Final Outcome

The top-level `on-prem` Flux graph now converges successfully on one revision:

- `on-prem-platform-core`
- `on-prem-keycloak-secrets`
- `on-prem-bigbang`
- `on-prem-bigbang-source`
- `on-prem-bigbang-foundation`
- `on-prem-bigbang-policy`
- `on-prem-bigbang-observability`
- `on-prem-platform-runtime`
- `on-prem-platform-services`

This is the first stable state reached after the Big Bang split work and the
associated live-state recovery sequence.

## Starting Failure Mode

The original failure condition was not one isolated bug. It was a layered
control-plane failure:

1. a schema/config error in the Big Bang values path stalled `on-prem-bigbang`
2. the health-gated graph then blocked downstream runtime and services work
3. later corrective Git commits did not produce a crisp or trustworthy
   controller response
4. multiple stale child-release teardown paths and namespace finalizers kept
   re-entering the graph as blockers during split rollout

The practical impact was loss of operator confidence: desired state, live state,
and controller behavior no longer had a predictable relationship.

## Root Causes That Were Actually Proven

### 1. Oversized Health-Gated Reconciliation Units

The original top-level graph concentrated too much failure blast radius in
`on-prem-bigbang`, then compounded it with a second broad gated unit in
`on-prem-platform-runtime`.

Consequence:

- one schema/config fault blocked unrelated downstream work

### 2. Stale Reconcile State Required Explicit Intervention

The original `bigbang` incident proved that corrected inputs in Git and even in
live generated values were not always enough to self-heal a failed release.

Proven recovery:

- `flux reconcile helmrelease bigbang -n bigbang --force`

### 3. Namespace Ownership and Resource Ownership Were Implicit and Inconsistent

Several runtime failures came from units managing resources in namespaces they
did not create or guarantee.

Examples:

- `platform-core` managed default service accounts for namespaces it did not own
- `platform-runtime` expected `kyverno/ghcr-secret` even though no `kyverno`
  namespace existed in the live split state
- runtime glue still assumed `argocd` and `alloy` ownership details that had
  become invalid during child-release teardown

### 4. Child Release Teardown Left Broken Live-State Debt

Multiple failures were not caused by current Git intent at all. They came from
stale live objects left behind by older ownership models:

- `ExternalSecret` finalizers blocking namespace deletion
- stale Kyverno webhook configurations pointing to nonexistent services
- old child HelmReleases stuck uninstalling or failing uninstall hooks
- operator-specific finalizers on Alloy custom resources

These were not theoretical risks; they directly blocked reconciliation.

### 5. The Big Bang Umbrella Chart Was Not Cleanly Splittable by Simple Values Alone

The split improved top-level blast radius and ultimately converged, but the
rollout proved that multiple Helm releases against the same Big Bang umbrella
chart still leaked shared/support resources across package families.

Evidence included:

- `bigbang-policy` touching `monitoring` and `prometheus-operator-crds`
- `kyvernoReporter` producing an invalid child HelmRelease in the policy lane
- child release state requiring targeted cleanup and package-scope narrowing

So the split was directionally useful, but the chart boundary was weaker than
initially assumed.

## Recovery Actions That Actually Worked

### Control-Plane Design Actions

1. audited the top-level Flux graph
2. classified `wait: true` usage explicitly
3. split Big Bang into:
   - source
   - foundation
   - policy
   - observability
4. repointed `platform-runtime` to the new Big Bang family units
5. removed the impossible `kyverno/ghcr-secret` health target from the runtime
   path

### Live-State Recovery Actions

1. forced Helm reconcile for the original stuck `bigbang` release
2. manually cleared stale `ExternalSecret` finalizers in terminating namespaces
3. manually removed stale Kyverno webhook configurations pointing to a dead
   service
4. manually cleared stale Alloy teardown state so the `alloy` namespace could be
   recreated
5. repeatedly used namespace state and child HelmRelease state as the truth
   source instead of relying on top-level status alone

## Repo Changes That Mattered Most

The following classes of repo changes directly contributed to eventual
convergence:

1. Big Bang split scaffolding and activation sequencing
2. moving foundation, policy, and observability ownership out of the monolith
3. narrowing `platform-core` default service account scope to namespaces it
   actually owns
4. disabling `kyvernoReporter` in the policy cutover path
5. removing `ghcr-secret.external-secret.yaml` from the runtime Kyverno bundle

These were not cosmetic cleanups. They closed concrete contract mismatches that
the live cluster proved were blocking reconciliation.

## What This Incident Changed in Practice

After this work, the operating posture is different:

1. top-level graph design is now treated as a first-class reliability concern
2. stale controller state is treated as a real incident class, not operator
   superstition
3. namespace ownership and health-gate contracts must be explicit
4. `kustomize build` is now baseline local validation for GitOps changes
5. live child-release and finalizer debt must be considered part of GitOps
   debugging, not an unrelated cluster-admin concern

## Residual Cleanup Debt

The top-level graph is green, but some cleanup debt may still remain beneath
that surface.

This should be audited separately:

1. stale child HelmReleases that are no longer authoritative but still exist
2. namespaces or support resources created during failed uninstall/remediation
   loops
3. child chart ownership that still crosses the intended foundation/policy/
   observability boundaries
4. `platform-runtime` scope, which still aggregates several distinct surfaces

This debt is now manageable because the top-level graph converges again.

## Recommended Follow-Through

### 1. Close `gitops#240` with Discipline

Do not close it as soon as the graph is green. Close it only after:

- this incident summary is accepted
- residual cleanup debt is enumerated
- the next control-plane follow-up issue(s) are created

### 2. Create Follow-Up Issues

Recommended follow-up themes:

- audit residual child HelmRelease debt after the split
- re-evaluate `platform-runtime` composition and possible decomposition
- normalize namespace/resource ownership contracts for remaining platform paths
- evaluate whether some Big Bang package families should eventually move to true
  package-level BYO releases rather than shared umbrella splits

### 3. Preserve the Operator Patterns

The following patterns should now be treated as standard operating knowledge:

- forced Helm reconcile for stale-but-corrected releases
- stale webhook removal when admission points at dead services
- finalizer removal when dead controllers block namespace teardown
- repo-side contract narrowing when a unit manages resources outside its actual
  ownership surface

## Bottom Line

This incident started as “the control plane does not react predictably.”

It ended with three durable conclusions:

1. top-level GitOps graph shape matters as much as individual manifests
2. stale live-state teardown is a first-class blocker in GitOps systems
3. control is restored by making ownership, gates, and recovery actions
   explicit, not by waiting longer
