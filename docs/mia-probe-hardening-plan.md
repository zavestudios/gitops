# Mia Probe Hardening Plan (Issue #26)

Status: implemented in sandbox (all probe phases stable)

Issue: https://github.com/zavestudios/gitops/issues/26

## Objective

Reintroduce probes for `mia` without creating restart loops.

## Constraints

- Runtime has shown delayed startup and loopback-only bind behavior in previous attempts.
- Initial deployment was intentionally stabilized with no probes before phased reintroduction.
- Any probe rollout must be gradual and reversible.

## Historical Baseline (Pre-Implementation)

- `tenants/mia/deployment.yaml` had no `startupProbe`, `readinessProbe`, or `livenessProbe`.
- This temporary state was used during early stabilization.

## Implementation Outcome

Implemented and validated in sandbox with phased rollout:

- Phase 1: `startupProbe` enabled and stable.
- Phase 2: `readinessProbe` added and stable.
- Phase 3: `livenessProbe` added and stable.

Observed result:
- deployment stable at desired replicas
- no probe-driven restart churn during observation window

## Phase 1: Startup Probe Only

Apply only `startupProbe` first and keep readiness/liveness disabled.

Target patch in `tenants/mia/deployment.yaml`:

```yaml
startupProbe:
  tcpSocket:
    port: 18789
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 90
```

Rationale:
- Up to 15 minutes startup budget.
- Avoid early restarts while process initializes.

Exit criteria:
- no startup-probe restarts for sustained period (30+ minutes)
- deployment remains stable at desired replicas

## Phase 2: Add Readiness Probe

After Phase 1 is stable, add readiness only.

Candidate:

```yaml
readinessProbe:
  tcpSocket:
    port: 18789
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 6
```

Rationale:
- readiness gates traffic without killing container.

Exit criteria:
- no readiness flapping
- service endpoints stay healthy

## Phase 3: Add Liveness Probe

Only after startup + readiness are stable.

Candidate:

```yaml
livenessProbe:
  tcpSocket:
    port: 18789
  periodSeconds: 30
  timeoutSeconds: 2
  failureThreshold: 3
```

Rationale:
- slower liveness cadence reduces false positives.

Exit criteria:
- zero probe-driven restarts during observation window

## Rollback Rule

If any phase causes repeated restarts or pod churn:

1. remove the newly added probe(s) from `tenants/mia/deployment.yaml`
2. reconcile GitOps
3. wait for deployment to return to stable state

## Validation Commands

**Requires cluster access:**

```bash
kubectl -n mia get deploy,rs,pods
kubectl -n mia describe pod <pod-name>
kubectl -n mia get events --sort-by=.lastTimestamp | tail -n 40
kubectl -n mia get deploy mia -o jsonpath='{.status.conditions[?(@.type=="Available")].status}{" "}{.status.conditions[?(@.type=="Progressing")].reason}{"\n"}'
```

## Change Policy

- land one phase per commit
- reconcile and observe before next phase
- use canary path if stable/unstable behavior diverges between images

## Post-Implementation Note (Kyverno Events)

- During rollout, Kyverno may continue to show historical `PolicyViolation` events for older ReplicaSets/images.
- For current-state triage, filter by active digest and recent timestamps.
- Treat old-digest `no signatures found` entries as historical noise unless they recur on the active digest.
