# Canary Rollout Pattern (Formation)

This document defines a practical canary workflow for tenant workloads during Formation.

This is an operational pattern, not contract-level `spec.delivery: canary` implementation.

## Purpose

- Validate candidate digests without destabilizing stable service.
- Collect reusable rollout artifacts for future tenant workloads.
- Keep promotion and rollback Git-driven.

## Ownership Model

- ArgoCD reconciles tenant workload resources under `tenants/*`.
- FluxCD reconciles platform resources and Argo Application registrations.

## Current Reference Implementation

- Stable workload: `tenants/mia/deployment.yaml`
- Canary workload: `tenants/mia/canary-deployment.yaml`
- Canary ingress host: `mia-canary-on-prem.zavestudios.com`

## Rollout Procedure

1. Pin stable deployment to known-good digest.
2. Set canary deployment digest to candidate signed digest.
3. Scale canary to `1` replica.
4. Validate canary runtime:
   - pod starts without crash loops
   - policy checks pass
   - endpoint responds via canary ingress
5. Promote:
   - copy candidate digest to stable deployment
   - keep canary at `0` (or delete canary resources)
6. Roll back:
   - restore prior stable digest
   - set canary to `0`

## Validation Checklist

- `kubectl -n <ns> get pods` shows stable and canary pod health as expected.
- No ongoing `PolicyViolation` for signature checks on candidate digest.
- Restart counts remain stable during validation.
- Stable service remains unaffected while canary is tested.

## Reusable Template

Use `tenants/_templates/canary/` to scaffold canary manifests for other workloads.
