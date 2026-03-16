# LLM Platform Migration Plan

This document moved to the `llm-platform` repository.

Canonical location:

- https://github.com/zavestudios/llm-platform/blob/main/docs/MIGRATION_PLAN.md

`gitops` remains the deployment-state authority for manifests and rollout state.
Architecture ownership for the shared LLM platform now lives with the platform service itself.

Every phase should preserve the previous working path until validation is complete.

## Recommended Next Changes

1. Update `mia` to depend on `LLM_BASE_URL` instead of `OLLAMA_HOST` plus direct provider assumptions.
2. Create shared GitOps manifests for `llm-gateway`.
3. Extend `oracle` job types around gateway-backed LLM execution.
4. Remove tenant-local `Ollama` only after Phase 1 is stable.
5. Add `vLLM` last, not first.

## Non-Goals

- Replacing `mia` as the chat/channel gateway
- Replacing `oracle` with model-serving software
- Treating `k8s-mcp` as part of the inference plane
- Building a full self-hosted stack before demand is proven
