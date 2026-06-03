# Residual Child HelmRelease Debt Audit

**Date:** 2026-06-03

**Purpose:** Inventory the residual child `HelmRelease` and related live-state
debt exposed by the `#240` Big Bang split and recovery sequence, and separate
what must be cleaned now from what can be tracked as managed follow-up.

**Owning issue:** `zavestudios/gitops#255`

## Scope

This audit is intentionally narrower than the full `#240` incident summary.

It focuses on debt classes that sat below the top-level Flux graph but still
re-entered the control plane as blockers:

- child `HelmRelease` objects that were no longer the intended authority
- child releases stuck in failed, uninstalling, or remediating states
- terminating namespaces held open by stale finalizers
- uninstall hooks, webhook configs, and support resources that outlived their
  owning release

This document is based on:

- the merged `docs/gitops240-incident-summary-2026-06.md`
- prior troubleshooting notes in `gitops/docs/`
- the live-state evidence captured during the `#240` recovery session

Because `gitops` does not have direct cluster authority, anything about current
live state after the final green graph must be treated as **verification
required**, not presumed truth.

## Why This Matters

The top-level graph now converges, but `#240` proved that top-level `Ready=True`
was not enough to trust the cluster.

Residual child-release debt matters because it can:

- keep old ownership models alive beneath a green parent graph
- reintroduce terminating namespaces and stale finalizers
- keep uninstall or remediation loops active long after the desired owner has
  changed
- produce false or delayed controller signals when later work touches the same
  package families

The goal is not to remove every historical artifact immediately.
The goal is to make the remaining debt explicit and classify it correctly.

## Classification Legend

- `Immediate cleanup`: debt that can plausibly re-block normal reconciliation
  and should be verified or removed promptly
- `Managed follow-up`: debt that should be audited and normalized, but does not
  by itself justify re-entering emergency mode while the top-level graph is
  green
- `Closed by repo change`: debt class that was narrowed structurally in Git and
  should now be watched rather than rediscovered

## Incident-Proven Debt Inventory

| Item | Observed during `#240` | Failure class | Current disposition | Recommended next step |
| --- | --- | --- | --- | --- |
| Old `HelmRelease/bigbang/alloy` | Yes | stuck uninstall with broken pre-delete hook image and stale uninstall path | Immediate cleanup | Verify whether old child Alloy HR still exists or still reports failed/uninstalling state. If yes, remove stale release history and support artifacts. |
| Old `HelmRelease/bigbang/argocd` | Yes | repeated install/uninstall remediation against a terminating `argocd` namespace | Immediate cleanup | Verify whether the child ArgoCD release is now healthy, recreated cleanly, or still carrying stale history from the terminating-namespace failure. |
| Old `HelmRelease/bigbang/kyverno` | Yes | uninstall failure and downstream dependency poison for `kyverno-policies` | Immediate cleanup | Verify whether old Kyverno child releases still exist in failed/uninstalling state and whether policy now owns the only live authority path. |
| Old `HelmRelease/bigbang/external-secrets` | Yes | uninstalling/state ambiguity during split recovery | Managed follow-up | Verify whether the old child release still exists or whether the foundation lane now cleanly owns the package. |
| Old `HelmRelease/bigbang/keycloak` | Yes | uninstalling/state ambiguity while namespace teardown was blocked | Managed follow-up | Verify whether old child release history still exists beneath the new foundation owner. |
| `ExternalSecret` finalizers in `keycloak` | Yes | namespace termination blocked by dead cleanup finalizer path | Closed by live repair, but class remains open | Treat as a reusable failure class. Verify no residual terminating namespace or orphan `ExternalSecret` remains. |
| `ExternalSecret` finalizers in `argocd` | Yes | namespace termination blocked by dead cleanup finalizer path | Closed by live repair, but class remains open | Same as `keycloak`: verify absence of orphan finalizers or terminating namespace state. |
| stale Kyverno webhook configs | Yes | admission deadlock against nonexistent `kyverno-kyverno-svc` | Immediate cleanup | Verify that no stale Kyverno webhook configs remain from the broken ownership window. |
| Alloy CR finalizers in terminating `alloy` namespace | Yes | namespace blocked by operator-specific uninstall finalizers | Managed follow-up | Verify no residual Alloy CRs or operator uninstall finalizers remain in `alloy`. |
| stale uninstall hook jobs and hook support resources | Yes | dead hook execution paths (`InvalidImageName`, missing RBAC, leftover jobs) | Immediate cleanup | Audit namespaces touched by split packages for leftover uninstall/remediation jobs and hook-only RBAC. |

## Item Notes

### Old child `HelmRelease` objects are the highest-value audit target

The repeated control-plane pattern was:

1. ownership moved in Git
2. top-level units became green
3. old child releases still existed underneath with failed, uninstalling, or
   remediating state

Those child releases were not harmless:

- they kept trying to uninstall or remediate against terminating namespaces
- they held old release history and stale controller messages
- they obscured whether the new owner had actually taken clean authority

The highest-value immediate audit is therefore:

- `argocd`
- `alloy`
- `kyverno`
- `kyverno-policies`
- `external-secrets`
- `keycloak`

not because all six must still be broken, but because those were the package
families that proved capable of poisoning later reconciliation.

### Finalizer debt must be treated as GitOps debt, not cluster side-noise

The incident repeatedly demonstrated that stale finalizers were not an
incidental runtime problem.

They became direct blockers for:

- `on-prem-keycloak-secrets`
- `on-prem-platform-runtime`
- `on-prem-platform-core`
- package-scoped Big Bang child releases

So the durable lesson is:

- namespace finalizer deadlocks belong in the `gitops` operating model
- they should be enumerated and tracked alongside release ownership changes

### Broken uninstall hooks are a separate debt class from failed releases

The old Alloy uninstall path is the clearest example:

- the issue was not simply "Alloy failed"
- the issue was "the pre-delete hook path itself was invalid and could never
  self-heal"

That class deserves its own audit lens:

- hook jobs
- hook-only service accounts / roles / rolebindings
- dead hook images
- stale hook annotations that remain after ownership has moved

## Repo-Side Changes That Already Reduced This Debt

These changes do not eliminate the live-state debt automatically, but they did
remove several contract mismatches that were feeding it:

1. Big Bang split into `source`, `foundation`, `policy`, and `observability`
2. `platform-core` default service account scope narrowed to namespaces it
   actually owns
3. `kyvernoReporter` disabled in the policy lane
4. impossible `kyverno/ghcr-secret` health target removed from
   `platform-runtime`

These should be treated as `Closed by repo change` only at the contract layer.
They do not prove that the old live artifacts are gone.

## Immediate Verification Checklist

The following checks should be run next before declaring `#255` complete.

**Requires cluster access:**
```bash
kubectl get helmrelease -A
kubectl get helmrelease -A | egrep 'alloy|argocd|external-secrets|keycloak|kyverno'
kubectl get ns
kubectl get ns | egrep 'alloy|argocd|keycloak|kyverno'
kubectl get mutatingwebhookconfigurations,validatingwebhookconfigurations | grep -i kyverno
kubectl get jobs -A | egrep 'alloy|argocd|kyverno|cleanup|finalizer|upgrade'
```

What to record:

- any child `HelmRelease` still `False`, `Unknown`, `uninstalling`, or
  repeatedly remediating
- any namespace still `Terminating`
- any stale Kyverno webhook configuration still pointing at a dead service
- any hook job or hook-support RBAC that no longer has a legitimate owner

## Decision Table

Use this decision table during the live audit.

| Verification result | Interpretation | Action |
| --- | --- | --- |
| old child release is gone | no residual live debt for that item | mark closed in `#255` |
| old child release exists but is healthy and still intentionally owned | no cleanup needed, but document surviving owner contract | move to `#257` if ownership is ambiguous |
| old child release exists and is failed/uninstalling/remediating | real residual debt | create cleanup PR/issue or remove live stale object via human-operated repair |
| namespace still terminating | stale finalizer or dead controller path remains | treat as immediate cleanup |
| stale webhook config still exists | admission deadlock can recur | remove or normalize immediately |
| leftover hook job/RBAC remains with no current owner | stale teardown artifact | clean up and document owner boundary |

## Recommended Disposition by Theme

### Immediate cleanup candidates

- stale child `HelmRelease` objects for `alloy`, `argocd`, and `kyverno`
- any remaining terminating namespaces in Big Bang-managed families
- stale Kyverno webhook configs
- leftover uninstall/remediation hook jobs

### Managed follow-up candidates

- surviving child release history for `external-secrets` and `keycloak`
- lingering but healthy package-scoped resources whose owner is no longer
  obvious
- any shared support resources whose correct lane is still ambiguous between
  Big Bang family units and `platform-runtime`

### Should be handed off to later issues

- unclear namespace/resource ownership boundaries:
  move to `#257`
- over-broad runtime composition questions:
  move to `#256`
- weak umbrella-chart package boundaries:
  move to `#258`

## Success Condition for `#255`

`#255` should be considered complete only when:

1. the residual child-release inventory is explicit
2. each item is classified as:
   - gone
   - healthy and intentional
   - stale and cleanup-required
3. any cleanup-required item is either:
   - fixed directly, or
   - split into a smaller follow-up issue with a named owner

The issue should not stay open just because historical artifacts once existed.
It should stay open only until the current live residual debt is known and
dispositioned.
