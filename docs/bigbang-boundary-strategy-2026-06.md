# Big Bang Boundary Strategy

**Date:** 2026-06-21

**Owning issue:** `zavestudios/gitops#258`

**Status:** Recommendation pending review

## Decision Question

Should the current foundation, policy, and observability releases remain
separate instances of the Big Bang umbrella chart, or should package families
move to directly owned package releases?

## Recommendation

Treat the current multi-release umbrella split as a stabilization boundary, not
the long-term ownership model.

Move every enabled package to a directly owned Flux `GitRepository` and
`HelmRelease` in controlled waves. Keep the current umbrella releases only
until their enabled packages have migrated and passed declared, rendered,
controller, runtime, and user-visible validation.

Use Kiali as the first extraction pilot. Migrate the Istio stack last and as one
coordinated family. Do not combine package extraction with package upgrades.

## Ownership Models

### Current family split

The repository owns three parent `HelmRelease` objects, but each parent still
runs the Big Bang umbrella chart. The umbrella then generates package sources,
package releases, namespaces, shared values, and support resources.

This reduces top-level blast radius but preserves two control layers:

```text
Flux Kustomization
  -> Big Bang umbrella HelmRelease
    -> package GitRepository and HelmRelease
      -> package resources
```

### Package-level ownership

The repository owns each package source and release directly:

```text
Flux Kustomization
  -> package GitRepository and HelmRelease
    -> package resources
```

This recommendation uses **package-level ownership** to mean direct Flux
ownership of the Big Bang package chart. It does not mean adding custom
packages back through the umbrella chart's `packages` values map.

Big Bang package guidance explicitly requires package charts to operate without
the umbrella, while the umbrella is responsible for injecting shared values
and support resources. Direct ownership is therefore technically supported,
but the repository must replace every required injected value and resource
explicitly.

References:

- [Big Bang 3.17 package Flux integration](https://docs-bigbang.dso.mil/3.17.0/docs/developer/package-integration/flux/)
- [Big Bang 3.17 package management](https://docs-bigbang.dso.mil/3.17.0/docs/concepts/package-management/)
- [Big Bang 3.17 values hierarchy](https://docs-bigbang.dso.mil/3.17.0/docs/concepts/values-guide/)
- [Upstream Istio package consolidation work](https://repo1.dso.mil/big-bang/bigbang/-/work_items/2273)

## Evidence

The `#240` rollout proved that multiple umbrella releases do not create strong
package ownership boundaries:

- the policy release rendered support resources associated with monitoring and
  `prometheus-operator-crds`
- `kyvernoReporter` generated an invalid child release and had to be disabled
- stale child releases continued uninstall and remediation behavior after
  parent ownership changed
- Alloy, ArgoCD, Kyverno, External Secrets, and Keycloak left child-release or
  namespace teardown debt
- operators had to trace truth through parent values, generated child releases,
  package releases, and live resources

The current values also contain substantial package-specific post-rendering and
hardening. This repository is already making package-level decisions, but those
decisions are expressed through an extra umbrella layer.

## Package Disposition

| Package or family | Current family | Long-term disposition | Migration wave | Reason |
| --- | --- | --- | --- | --- |
| Kiali | foundation | direct package ownership | pilot | operationally separable from mesh installation; prior child-release debt makes ownership clarity valuable; lower blast radius than mesh or policy |
| ArgoCD | foundation | direct package ownership | 1 | independent app-delivery control plane with extensive local hardening and prior teardown debt |
| Keycloak | foundation | direct package ownership | 1 | custom image, external database, ingress, and secret contracts are already repository-specific |
| External Secrets | foundation | direct package ownership | 2 | shared prerequisite for many workloads; direct ownership is desirable but requires careful CRD and webhook continuity |
| Vault | foundation | direct package ownership | 2 | storage, auto-unseal, mesh, and secret contracts are heavily environment-specific; migrate after prerequisite inventory and rollback are proven |
| Kyverno and Kyverno Policies | policy | direct ownership as one ordered family | 3 | admission and CRD ordering are tightly coupled; prior webhook and uninstall failures make a separate direct control surface necessary |
| Kyverno Reporter | policy, disabled | do not migrate | none | no current platform requirement; enabling it previously produced an invalid child release |
| Monitoring and Grafana | observability | direct ownership as one ordered family | 4 | shared CRDs, dashboards, and scrape contracts require coordinated sequencing but not umbrella ownership |
| Tempo, Loki, and Alloy | observability | direct ownership as one ordered family | 4 | the telemetry data path is coupled; direct package releases should preserve explicit endpoint and finalizer contracts |
| Istio CRDs, Istiod, and gateways | foundation | direct ownership as one coordinated mesh family | last | cluster-wide traffic and CRD blast radius is highest; upstream is also working toward a consolidated Istio package boundary |

The wave number defines sequence, not pull request size. Each package should
move in its own pull request unless two packages share an inseparable ownership
handoff.

## Why No Family Stays Under the Umbrella Long Term

The umbrella remains useful as a distribution and integration reference, but
it is not the right lifecycle authority for this environment:

1. Flux is already the platform state authority.
2. Package versions and values are already pinned and customized here.
3. Parent releases add reconciliation indirection without eliminating local
   package decisions.
4. Shared umbrella templates weakened the intended family boundaries during
   the split.
5. Direct package releases isolate history, remediation, drift, and rollback.

Keeping only one family under the umbrella would retain the parent control
layer and its support-resource ownership for diminishing benefit. The Istio
family should remain there temporarily because migration risk is high, not
because the umbrella is its desired final owner.

## Migration Preconditions

Before extracting any package:

1. record the package chart source and exact version generated by Big Bang
   `3.17.0`
2. render and retain the current package release values
3. inventory umbrella-generated namespaces, secrets, network policies,
   authorization policies, virtual services, and image pull secrets
4. identify CRDs and controller dependencies
5. define a package-specific rollback that restores the current umbrella owner
6. prove there will be no interval with two active owners for the same package

Package extraction must preserve versions first. Upgrades belong in later pull
requests after direct ownership is stable.

## Validation Standard

Every migration must compare all five diagnostic boundaries:

1. **Declared truth:** direct package source, release, values, and dependencies
   are explicit in Git.
2. **Rendered truth:** direct rendering matches the required behavior of the
   current generated package release.
3. **Controller truth:** the direct Flux release is ready and the old child
   release no longer reconciles.
4. **Runtime truth:** package workloads, CRDs, webhooks, storage, and finalizers
   are healthy.
5. **User-visible behavior:** ingress, authentication, policy admission, or
   telemetry behavior remains equivalent.

Runtime and user-visible checks require a human operator with cluster access.

## Execution Issues

Create separate repository issues in this order:

1. [`#300`](https://github.com/zavestudios/gitops/issues/300): inventory
   generated package versions, values, and umbrella-owned support resources
2. extract Kiali as the package-level ownership pilot
3. extract ArgoCD and Keycloak in separate changes
4. extract External Secrets, then Vault
5. extract Kyverno and Kyverno Policies as an ordered family
6. extract the observability packages in dependency order
7. extract the Istio family and remove the remaining umbrella resources

Each issue must name its rollback path, acceptance evidence, and explicit
ownership handoff. The Command Center should track the migration program as one
coordination item while execution remains in these repository issues.

## Consequences

### Positive

- package failures and remediation histories are isolated
- declared truth is closer to rendered and controller truth
- namespace, CRD, secret, and policy ownership becomes reviewable in Git
- package upgrades no longer require reconciling unrelated umbrella families
- rollback can be scoped to one package owner

### Cost

- shared values and support resources currently injected by Big Bang must be
  owned explicitly
- the repository assumes package integration and upgrade responsibility
- migration requires careful live-state handoff and cannot be validated from
  repository state alone
- the temporary graph becomes larger while old and new ownership models coexist

## Completion Condition for `#258`

This recommendation is complete when it is accepted and the first inventory
execution issue exists. Package migration is downstream execution and must not
keep the architecture decision issue open.
