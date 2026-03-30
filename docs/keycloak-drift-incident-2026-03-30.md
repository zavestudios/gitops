# Keycloak Drift Incident - 2026-03-30

Status: mitigation proposed

## Symptom

Keycloak appeared absent from the cluster:

- no `HelmRelease/keycloak` in namespace `bigbang`
- no obvious Keycloak workload objects

## Boundary Findings

### Declared Truth

- `gitops` `main` still declared Keycloak enabled in `bigbang/values.yaml`
- `clusters/on-prem/kustomization.yaml` still included
  `keycloak-secrets-kustomization.yaml`
- `clusters/on-prem/bigbang-kustomization.yaml` still depended on
  `on-prem-keycloak-secrets`

### Controller Truth

- `flux-system` source revision was current at `main@sha1:f54e6fe4`
- `on-prem-bigbang` was `Ready`
- `on-prem-keycloak-secrets` was `Ready`
- parent `HelmRelease/bigbang` was `Ready`

### Rendered Truth

- parent `HelmRelease/bigbang` referenced `ConfigMap/bigbang-values-56ttc6d5tt`
- that ConfigMap contained the Keycloak block
- `helm get values -n bigbang bigbang -a` included `keycloak.enabled: true`
- `helm get manifest -n bigbang bigbang` contained child
  `HelmRelease/keycloak`

### Live Runtime Truth

- `GitRepository/bigbang/keycloak` existed and was healthy
- `HelmRelease/bigbang/keycloak` was missing from the live cluster
- after forced reconcile, recreated `HelmRelease/bigbang/keycloak` had:
  - Helm metadata and labels tying it to parent `bigbang`
  - no `ownerReferences`
  - normal Flux finalizer
  - successful install status

## Recovery Performed

Manual recovery:

```bash
flux reconcile helmrelease bigbang -n bigbang --force
```

Observed result:

- `HelmRelease/keycloak` reappeared
- Keycloak workload returned with 2 pods `READY`

## Current Assessment

Most likely failure class: live drift of the child `HelmRelease/keycloak`.

At time of recovery:

- desired state was intact
- parent rendered manifest still included the child release
- normal reconciliation had not reasserted the missing child object
- forced reconcile of parent `HelmRelease/bigbang` restored it

Additional evidence:

- parent `HelmRelease/bigbang` showed no visible `driftDetection` block
- `gitops` currently contains no `driftDetection` configuration
- installed helm-controller image was `ghcr.io/fluxcd/helm-controller:v1.4.5`
- CRD schema confirms `HelmRelease.spec.driftDetection.mode` supports
  `enabled`, `warn`, and `disabled`
- after recreation, child `HelmRelease/keycloak` emitted `DriftDetected` and
  `DriftCorrected` events for its own managed release resources
- event stream also showed Kyverno policy violations on Keycloak pod and
  StatefulSet objects, which may be relevant to runtime hardening but do not
  explain the missing child `HelmRelease`

## Open Questions

1. What deleted or removed `HelmRelease/keycloak` from live state?
2. Why did routine reconciliation not recreate it before the forced reconcile?
3. Was this manual deletion, controller behavior, or a Helm/Big Bang edge case?
4. Would enabling drift detection on the parent `HelmRelease/bigbang` cause
   missing child `HelmRelease` objects to self-heal?

## Next Checks

Focus next on:

- validating whether enabling drift detection on parent `HelmRelease/bigbang`
  causes missing child `HelmRelease` objects to self-heal during steady-state
  reconciliation
- labels, annotations, and owner semantics on recreated `HelmRelease/keycloak`
- recent events and controller logs around the deletion window
