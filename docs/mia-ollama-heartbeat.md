# Mia Ollama Heartbeat Deployment

This document captures the tenant-scoped Ollama pattern used by `mia` for heartbeat cost optimization.

## Scope and Governance

- Ollama is deployed in namespace `mia` as a tenant dependency.
- It is not a shared platform service.
- If other tenants require Ollama, promote to platform scope with separate governance review.

## Components

- `tenants/mia/ollama-pvc.yaml`: persistent model cache (`/root/.ollama`)
- `tenants/mia/ollama-deployment.yaml`: Ollama server pod
- `tenants/mia/ollama-service.yaml`: internal ClusterIP on port `11434`
- `tenants/mia/deployment.yaml`:
  - `ANTHROPIC_API_KEY` from `mia-provider` secret
  - `OLLAMA_HOST=http://ollama.mia.svc.cluster.local:11434`

## OpenClaw Config Expectation

`mia` runtime config should include:

- primary model: `anthropic/claude-haiku-4-5`
- model aliases (`haiku`, `sonnet`)
- heartbeat model: `ollama/llama3.2:3b`

## Prerequisites

- `mia-provider` secret contains key `ANTHROPIC_API_KEY`.
- Cluster has storage class available for the PVC.

## Rollout Steps

1. Merge/push `mia` config update.
2. Merge/push `gitops` tenant manifest updates.
3. Reconcile controllers.

**Run manually by human:**

```bash
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization flux-system -n flux-system
```

4. Pull Ollama model once after pod starts.

**Run manually by human:**

```bash
kubectl -n mia exec deploy/ollama -- ollama pull llama3.2:3b
```

## Validation

**Run manually by human:**

```bash
kubectl -n mia get deploy,svc,pods
kubectl -n mia exec deploy/mia -- openclaw status --json
kubectl -n mia logs deploy/mia --tail=120 | grep -i "heartbeat\\|agent model"
```

Expected:

- `deployment/ollama` available and serving port `11434`
- `mia` pod healthy under startup/readiness/liveness probes
- heartbeat configured for `ollama/llama3.2:3b`
