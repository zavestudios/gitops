# Observability Review Record

**Date:** 2026-05-17

**Purpose:** Capture the current observability decision and immediate rollout path now that the shared Alloy receiver, Mia/OpenClaw runtime upgrade, and operator access path are working.

## Current Baseline

The following are now materially true:

- the shared Alloy receiver path is live
- tenant OTLP export can target `alloy-receiver.alloy.svc.cluster.local:4318`
- `mia` is upgraded to a compatible OpenClaw runtime
- gateway token auth and owner allowlist posture are working in-cluster
- dashboard access and interactive Mia round-trip were validated
- incident notes are captured in [alloy-receiver-troubleshooting-notes-2026-05.md](/Users/xavierlopez/Dev/gitops/docs/alloy-receiver-troubleshooting-notes-2026-05.md)

The primary remaining tenant-specific tracing validation is still:

- explicit end-to-end OTEL verification into Tempo, tracked in `zavestudios/mia#30`

## Decision

Observability should be treated as a **hybrid platform concern**:

- a shared platform service surface for collection, storage, query, and access
- a workload capability surface for contract-declared intent

This matches the platform reality better than either extreme alone.

Why:

- shared ingest path
- cross-tenant consumption
- policy and security implications
- control-plane ownership boundaries
- operator workflow requirements
- contract and GitOps materialization implications

## Current State

### Shared runtime and access

- Grafana, Loki, Prometheus, Tempo, and Alloy are shared platform surfaces
- the main runtime ownership remains in `gitops`, largely via Big Bang values
- some runtime glue now exists directly in `gitops/platform/runtime/`, most notably the explicit Alloy receiver path

### Tracing path

- the shared Alloy receiver path is live
- tenant OTLP export can target `alloy-receiver.alloy.svc.cluster.local:4318`
- `mia` is the first tracing validation workload
- the remaining missing proof is runtime end-to-end verification into Tempo

### Metrics path

- the current platform contract still defines `metrics` as a Prometheus-style scrape capability
- `rigoberta` already materializes that pattern with a `ServiceMonitor`
- `mia` does not currently materialize Prometheus scrape objects, so it should not be treated as the metrics validation workload

## Ownership Boundaries

### `platform-docs`

- classify observability
- define capability semantics
- define completion criteria and rollout rules

### `gitops`

- install and reconcile the shared stack
- publish the shared collector and routing path
- materialize tenant-side config needed for the governed path

### Tenant repos

- declare only capabilities that are actually materialized
- own workload-local instrumentation and config
- do not own bespoke backend topology as the default platform path

## Canonical Operator Workflow

The target operator workflow for governed workloads is:

```text
request -> logs -> metrics -> trace
```

Interpretation in the current stack:

- logs: inspect the workload's log stream in Loki/Grafana
- metrics: inspect Prometheus-backed workload metrics in Grafana
- trace: pivot from request behavior into Tempo for distributed tracing

## Immediate Rollout Rules

1. Keep `mia` as the tracing validation workload.
2. Use `rigoberta` as the metrics materialization example until another workload proves the canonical `metrics` path.
3. Do not let tenant contracts claim capability completion ahead of GitOps materialization.
4. Convert runtime recovery notes into durable operator-facing verification steps.

## Manual Verification Steps

### Mia tracing verification

**Requires cluster access:**

```bash
kubectl get deployment -n mia mia -o yaml | rg 'OTEL_EXPORTER_OTLP_ENDPOINT|OTEL_EXPORTER_OTLP_PROTOCOL|OTEL_SERVICE_NAME'
kubectl get svc -n alloy alloy-receiver
kubectl logs -n alloy deployment/alloy-receiver --since=15m
```

Expected checks:

- `mia` publishes `OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy-receiver.alloy.svc.cluster.local:4318`
- the `alloy-receiver` Service exists in namespace `alloy`
- receiver logs show OTLP ingestion without repeated export failures

### Rigoberta metrics verification

**Requires cluster access:**

```bash
kubectl get servicemonitor -n rigoberta rigoberta
kubectl get service -n rigoberta rigoberta -o yaml | rg 'name: metrics'
kubectl get endpoints -n rigoberta rigoberta
```

Expected checks:

- the `ServiceMonitor` exists
- the workload `Service` exposes a named `metrics` port
- endpoints exist behind that `Service`

### Operator UI follow-through

Use the operator surfaces already modeled for the current environment:

- Grafana for logs, dashboards, and Tempo pivoting
- Tempo for trace confirmation through Grafana data-source integration
- Prometheus-backed dashboards for workload metrics

## Follow-Through

This review changes the shape of the execution work:

1. `mia#30` remains the tracing verification issue.
2. `gitops#190` should treat metrics and tracing as separate validation tracks, not a single workload proof.
3. `platform-docs` should carry the durable classification and ownership model.

## Execution Anchors

- `zavestudios/gitops#190`
- `zavestudios/mia#30`
- `zavestudios/platform-docs#79`
- [alloy-receiver-troubleshooting-notes-2026-05.md](/Users/xavierlopez/Dev/gitops/docs/alloy-receiver-troubleshooting-notes-2026-05.md)
