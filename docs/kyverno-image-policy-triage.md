# Kyverno Image Policy Triage (Active vs Historical)

Use this when `require-signed-ghcr-images` events appear during/after rollouts.

## 1) Get active digest

**Run manually by human:**

```bash
kubectl -n mia get deploy mia -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

## 2) Confirm current verify result on live deployment

**Run manually by human:**

```bash
kubectl -n mia get deploy mia -o jsonpath='{.metadata.annotations.kyverno\.io/verify-images}{"\n"}'
```

Expected for healthy state:
- active digest appears with `"pass"`.

## 3) Filter policy events for active digest only

**Run manually by human:**

```bash
ACTIVE_DIGEST="$(kubectl -n mia get deploy mia -o jsonpath='{.spec.template.spec.containers[0].image}' | sed 's|.*@||')"
kubectl -n mia get events --sort-by=.lastTimestamp | grep -F "${ACTIVE_DIGEST}" | grep -i PolicyViolation
```

Interpretation:
- no output (or old timestamps only) means no active-digest violation.
- violations only for old digests/ReplicaSets are historical noise.

## 4) Spot historical noise quickly

**Run manually by human:**

```bash
kubectl -n mia get events --sort-by=.lastTimestamp | grep -i "require-signed-ghcr-images" | tail -n 30
```

If these lines reference non-active digests, treat as historical unless they recur on the active digest.
