# Alloy Receiver Troubleshooting Notes

**Status:** Resolved
**Started:** 2026-05-09
**Resolved:** 2026-05-17
**Scope:** Scratch incident log for Alloy receiver materialization, Big Bang package drift, and Kyverno policy interaction
**Owning repo:** `gitops`
**Related repo(s):** `platform-docs` for operating-model follow-through and decision capture

## Resolved Outcome

- all `HelmRelease` objects returned to `Ready=True`
- `kyverno-policies` recovered and now reconciles successfully
- `istiod` converged onto the corrected ReplicaSet and is healthy
- `alloy-receiver` is now materialized as shared runtime substrate:
  - `Deployment/alloy-receiver`
  - `Service/alloy-receiver`
  - OTLP ports `4317` and `4318`
- the live receiver endpoint is now available in-cluster at:
  - `alloy-receiver.alloy.svc.cluster.local:4317`
  - `alloy-receiver.alloy.svc.cluster.local:4318`

This note remains incident history, not a formal runbook.

## Purpose

Capture the troubleshooting chain that turned a simple tracing enablement task into a multi-control-plane incident:

- Big Bang wrapper/render-path mismatch
- Helm hook lifecycle breakage
- Kyverno policy package deadlock
- automount posture conflicts for legitimate control-plane workloads
- explicit receiver runtime ownership
- `istiod` rollout convergence

## Repo Scope

Per `platform-docs/_platform/REPO_TAXONOMY.md` and `GITOPS_MODEL.md`:

- `gitops` was the primary owning repository throughout this incident
- `platform-docs` is related only for doctrine and follow-up decision capture
- no substrate-repo changes were required

Current assessment:
- this was a **single-repo** incident in implementation, even though the runtime symptoms crossed multiple control planes

## Initial Goal

Materialize a shared OTLP receiver for tenant tracing, specifically to support `mia` sending traces into Tempo through Alloy.

Expected surface:

- an Alloy-managed receiver runtime in namespace `alloy`
- a service exposing:
  - `4317` for OTLP gRPC
  - `4318` for OTLP HTTP

## Boundary Ladder

Investigation crossed these layers repeatedly:

1. Declared truth
   - `gitops/bigbang/values.yaml`
   - `gitops/platform/runtime/alloy-receiver/`
2. Rendered truth
   - Big Bang values secrets such as:
     - `bigbang-alloy-values`
     - `bigbang-kyverno-policies-values`
     - `bigbang-istiod-values`
   - `helm get manifest`
3. Controller truth
   - Flux `Kustomization`
   - Flux `HelmRelease`
   - Alloy operator reconciliation
4. Live runtime truth
   - `Deployment`, `Service`, `ServiceAccount`, `Job`, `ReplicaSet`, `Pod`, events, and logs
5. User-visible behavior
   - whether tracing substrate actually existed for tenant use

## Main Failure Classes

### 1. Alloy hook lifecycle failure

The upstream Alloy finalizer hook job existed, but its support RBAC resources were absent at execution time.

Observed symptom:

- `serviceaccount "alloy-upstream-add-finalizer" not found`

Durable fix:

- added durable Flux-managed hook support resources in `platform/runtime/alloy-hook-support/`

### 2. Hook image / render-path mismatch

The hook continued to render:

- `image: /grafana/helm-chart-toolbox-kubectl:0.1.2`
- `sidecar.istio.io/inject: "false"`

Important lesson:

- the correct upstream values path was not the first one assumed
- wrapper/render-path debugging was required

Pragmatic fix:

- disable Alloy Helm hooks at the Big Bang package layer

### 3. Wrapped Alloy chart would not materialize the receiver collector

The values secret contained the intended receiver inputs, but the wrapped chart only rendered the logs collector.

Observed facts:

- `applicationObservability.collector: alloy-receiver`
- `collectors.alloy-receiver.presets: [deployment]`
- rendered release still only produced `Alloy/alloy-alloy-logs`

Durable fix:

- stop depending on the wrapper for this slice
- create the receiver explicitly in `platform/runtime/alloy-receiver/`

### 4. Kyverno policy package deadlock

`HelmRelease/bigbang/kyverno-policies` became wedged trying to patch:

- `ClusterPolicy/update-automountserviceaccounttokens`

Failure mode:

- Kyverno validating webhook timeout
- repeated upgrade and rollback failure

Durable fix:

- disable both:
  - `update-automountserviceaccounttokens`
  - `update-automountserviceaccounttokens-default`

Important lesson:

- the values override landed in the secret, but only `helm get manifest` proved whether the policy family still rendered

### 5. Automount posture mismatch for legitimate controllers

Several platform controllers legitimately require Kubernetes API credentials and broke once automount hardening became effective.

Confirmed affected workloads:

- `alloy-alloy-operator`
- `kiali-kiali-kiali-operator`
- `monitoring-monitoring-kube-state-metrics`

Common failure signature:

- missing `/var/run/secrets/kubernetes.io/serviceaccount/token`
- in-cluster config initialization failure

Durable fix:

- add narrow policy exclusions for those deployments
- restore pod-template token mount behavior where `gitops` itself was forcing `automountServiceAccountToken: false`

### 6. `istiod` rollout convergence failure

`istiod` initially remained stuck on an old ReplicaSet with requests:

- `cpu: 500m`
- `memory: 2Gi`

Symptoms:

- old RS pods remained pending on insufficient memory
- new RS partially came up but Helm timed out before convergence

Important discriminator:

- the corrected RS eventually proved the desired spec:
  - `cpu: 250m`
  - `memory: 512Mi`
  - `automountServiceAccountToken: true`

Durable fix:

- correct the effective Big Bang package values path for `istiod` resources
- restore token mount behavior for `istiod`
- let the corrected ReplicaSet fully replace the old one

### 7. Receiver-specific policy hardening gaps

Once the explicit receiver CR retried in a healthier platform state, additional admission failures became visible:

- generated `ServiceAccount/alloy-receiver` needed `automountServiceAccountToken: false`
- generated `config-reloader` needed `capabilities.drop: [ALL]`

Durable fix:

- set in `platform/runtime/alloy-receiver/alloy.yaml`:
  - `serviceAccount.automountServiceAccountToken: false`
  - `configReloader.securityContext.capabilities.drop: [ALL]`

## Files Changed

Primary files touched during the incident:

- `gitops/bigbang/values.yaml`
- `gitops/platform/runtime/kustomization.yaml`
- `gitops/platform/runtime/alloy-hook-support/`
- `gitops/platform/runtime/alloy-receiver/configmap.yaml`
- `gitops/platform/runtime/alloy-receiver/alloy.yaml`

## Final Receiver Shape

The explicit runtime receiver now exists as:

- `Alloy/alloy-receiver`
- `Deployment/alloy-receiver`
- `Service/alloy-receiver`

Exposed ports:

- `12345`
- `4317`
- `4318`

## Key Lessons

### Wrapper truth must be proven from rendered output

The values secret alone was not enough. Multiple times the real answer required:

- `helm get manifest`
- live `Deployment` / `ReplicaSet` inspection

### Vendored policy authority only helps if it is actually authoritative

There was likely a sound original reason to vendor Kyverno policy content, but the live authority remained the Big Bang `kyvernoPolicies` values path.

As long as that remains true, runtime debugging must follow the live package owner, not the vendored tree.

### Automount hardening is a migration, not a toggle

Some workloads truly should run with:

- `automountServiceAccountToken: false`

Others legitimately require Kubernetes API access and need narrow exceptions or explicit `true`.

### Platform runtime escape hatches are sometimes the right call

The explicit `Alloy/alloy-receiver` runtime ownership was the correct move once the wrapped chart repeatedly failed to materialize the desired substrate.

## Follow-Up Candidates

- make vendored Kyverno policy content truly authoritative, or remove the illusion that it is
- document which platform controllers are intentionally exempt from the automount baseline
- capture a repeatable pattern for explicit runtime ownership when wrapped Big Bang packages fail to materialize a shared capability
- validate tracing end-to-end from `mia` into Tempo now that the receiver exists

## Manual Runtime Checks

These require cluster access and must be run by a human.

**Run manually by human**

```bash
kubectl get hr -A
kubectl get deployment,svc,pods -n alloy | grep alloy-receiver
kubectl get svc -n alloy alloy-receiver -o wide
kubectl get deploy,rs,pods -n istio-system
```

## Promotion Trigger

Promote this note into a runbook or decision artifact if any of the following become true:

- the same Big Bang wrapper/render-path failure pattern repeats
- the same automount exception class appears in more than one package upgrade cycle
- explicit runtime ownership becomes a standard escape hatch for wrapped platform capabilities
- vendored-vs-live policy authority is formally resolved
