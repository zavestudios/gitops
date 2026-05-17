# Observability Review Outline

**Date:** 2026-05-17

**Purpose:** Review the current observability effort now that the shared Alloy receiver, Mia/OpenClaw runtime upgrade, and operator access path are working. This is no longer a bring-up/debugging stream. The focus is now service classification, operating model, and rollout path.

## Current Baseline

The following are now materially true:

- the shared Alloy receiver path is live
- tenant OTLP export can target `alloy-receiver.alloy.svc.cluster.local:4318`
- `mia` is upgraded to a compatible OpenClaw runtime
- gateway token auth and owner allowlist posture are working in-cluster
- dashboard access and interactive Mia round-trip were validated
- incident notes are captured in [alloy-receiver-troubleshooting-notes-2026-05.md](/Users/xavierlopez/Dev/gitops/docs/alloy-receiver-troubleshooting-notes-2026-05.md)

The primary remaining tenant-specific validation is still:

- explicit end-to-end OTEL verification into Tempo, tracked in `zavestudios/mia#30`

## Review Question

What class of service is observability at ZaveStudios, and what operating model should govern it?

The current implementation already behaves like more than an app-local integration:

- shared ingest path
- cross-tenant consumption
- policy and security implications
- control-plane ownership boundaries
- operator workflow requirements
- contract and GitOps materialization implications

That suggests observability should be treated as either:

- a platform shared service
- a platform capability
- or a hybrid of both

## Review Goals

1. Confirm service classification.
2. Confirm ownership boundaries across Big Bang, GitOps, tenants, and operator access.
3. Confirm canonical paths for logs, metrics, and traces.
4. Define the baseline operator workflow: request -> logs -> metrics -> trace.
5. Decide what should become doctrine and what should remain implementation detail.
6. Produce the next-step rollout path beyond `mia`.

## Suggested Structure

### 1. Current State

- which observability components are live now
- which parts are Big Bang-owned versus directly GitOps-owned
- which behaviors are verified versus only assumed

### 2. Service Classification

- should observability be treated as platform shared service, platform capability, or hybrid
- what that classification implies for ownership, support, and rollout

### 3. Control Plane And Ownership

- Big Bang-owned surfaces
- GitOps-owned surfaces
- tenant-owned instrumentation and export wiring
- operator access and auth model

### 4. Canonical Operator Workflow

- logs path
- metrics path
- traces path
- one legible journey for governed workloads:
  request -> logs -> metrics -> trace

### 5. Doctrine And Enforcement

- what belongs in `platform-docs`
- what should be enforceable through contracts or policy
- what should remain a local implementation pattern

### 6. Rollout Path

- `mia` as first tracing validation workload
- next candidate workloads for metrics and tracing standardization
- sequencing for broader platform adoption

## Suggested Outputs

- one explicit service-classification decision
- updated scope and follow-through on `zavestudios/gitops#190`
- any required `platform-docs` follow-up issues
- workload rollout follow-up issues for metrics and tracing standardization

## Execution Anchors

- `zavestudios/gitops#190`
- `zavestudios/mia#30`
- [alloy-receiver-troubleshooting-notes-2026-05.md](/Users/xavierlopez/Dev/gitops/docs/alloy-receiver-troubleshooting-notes-2026-05.md)
