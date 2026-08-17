# Mia v1 Retirement

## Decision

Mia v1 is retired.

The old runtime depended on a WhatsApp gateway identity hosted by a temporary
phone/account. That access path is no longer available and should not be
rebuilt as the foundation for the next autonomous-agent phase.

The replacement capability is `autonomous-agent`, classified as a
platform-service in `platform-docs/_platform/REPO_TAXONOMY.md`.

## Current GitOps State

The `mia` ArgoCD Application is retained temporarily for controlled retirement.

Desired runtime state is scaled to zero:

- `tenants/mia/deployment.yaml`
- `tenants/mia/ollama-deployment.yaml`
- `tenants/mia/canary-deployment.yaml`

PVCs, ExternalSecrets, Services, and namespace resources remain in Git until a
human with cluster access decides whether state should be archived, inspected,
or deleted.

## Do Not Migrate

- WhatsApp pairing credentials
- WhatsApp plugin persistence behavior
- phone-number allowlist secrets
- the `mia` namespace as the future capability identity
- tenant-scoped Ollama as the long-term model-access architecture

## Final Cleanup

After the v2 `autonomous-agent` path is represented in Git, remove the old
`mia` ArgoCD Application and tenant manifests by PR.

**Requires cluster access:**

- inspect whether `mia` pods are scaled to zero
- decide whether `mia-data` or `ollama-data` PVCs require archival
- confirm whether `mia-provider` and GHCR pull secrets should be revoked
- verify ArgoCD convergence after final manifest removal
- confirm no orphan resources remain in namespace `mia`

