# Vault Migration Plan

This document records the current GitOps-side Vault migration plan for the `gitops` repository.

Repository scope:

- `gitops` is the in-scope `infrastructure` repository for shared runtime mutation.
- `platform-docs` remains the authority for lifecycle, taxonomy, and GitOps control-plane rules.

## Decision on `bbctl`

Decision: do not deploy `bbctl` in-cluster as part of this migration.

Reasoning:

- The current repo already uses Flux and ArgoCD as the GitOps control plane.
- `bbctl` is an optional Big Bang management tool, not required to deploy Vault or External Secrets Operator.
- Adding another in-cluster management surface before Vault is stable would widen operational variance without reducing current migration risk.

Use `bbctl` only as an optional operator-side troubleshooting tool later if there is a concrete workflow gap that Flux, ArgoCD, Helm rendering, or Big Bang docs do not cover.

Reference:

- Big Bang documents `bbctl` as a CLI to simplify development, deployment, auditing, and maintenance, and notes it can run on developer machines, in pipelines, or in-cluster.

## Current State

The initial Vault-backed migration targets have now been moved to `ExternalSecret` resources:

- `tenants/mia/mia-provider.external-secret.yaml`
- `platform/cloudflare/cloudflared-token.external-secret.yaml`
- `platform/policies/kyverno/ghcr-secret.external-secret.yaml`
- `tenants/mia/ghcr-secret.external-secret.yaml`

Vault is already enabled in `bigbang/values.yaml`.

This change adds:

- Big Bang `externalSecrets` addon enabled
- A GitOps-managed `ClusterSecretStore` pointing at in-cluster Vault
- A dedicated `vault-reader` service account for ESO Vault authentication
- ordered Flux reconciliation across `platform/core`, `bigbang`, and `platform/runtime`

## Current Decision

Broader Vault migration is no longer blocked on basic integration viability or restart-time manual unseal.

Current status:

- External Secrets integration is in place and working
- the constrained `mia-provider` proof path succeeded
- Vault continuity was validated across pod and node restart
- AWS KMS auto-unseal has now been implemented and validated

Remaining caution:

- issue `#54` still matters for documenting lifecycle and durability expectations in the current environment
- broader migration can now resume deliberately, but it should still follow staged rollout rather than blind bulk cutover

Tracked follow-up work:

- `gitops#54` Harden Vault persistence and lifecycle behavior for the current environment
- `gitops#55` Rename the current environment and introduce a true local sandbox

## Migration Status

The initial staged migration set has now succeeded.

What was validated:

- Vault was initialized, unsealed, and configured for Kubernetes auth
- External Secrets Operator authenticated to Vault through the `vault-kv` `ClusterSecretStore`
- the `mia-provider` `ExternalSecret` synced successfully
- Kubernetes secret `mia-provider` was created in namespace `mia`
- the `cloudflared-token` `ExternalSecret` synced successfully
- the platform `ghcr-secret` `ExternalSecret` synced successfully in namespace `kyverno`
- the tenant `ghcr-secret` `ExternalSecret` synced successfully in namespace `mia`

What this means:

- the Vault and External Secrets functional integration path is now proven for both single-key opaque secrets and Docker config pull secrets
- Vault now returns unsealed after pod restart with AWS KMS auto-unseal
- `vault-kv` recovers without manual unseal after restart
- the remaining work is cleanup, documentation, and deciding how broadly to continue migration from here

## Completed Migration Order

Completed in this order:

1. `mia-provider`
2. `cloudflared-token`
3. platform GHCR pull secret (`platform/policies/kyverno/ghcr-secret`)
4. tenant GHCR pull secret (`tenants/mia/ghcr-secret`)

## Target Vault Layout

Use KV v2 at mount `secret` with paths:

- `secret/data/tenants/mia/provider`
- `secret/data/platform/cloudflare`
- `secret/data/platform/ghcr`
- `secret/data/tenants/mia/ghcr`

Suggested payloads:

```json
{
  "ANTHROPIC_API_KEY": "..."
}
```

```json
{
  "token": "..."
}
```

```json
{
  ".dockerconfigjson": "..."
}
```

## Manual Bootstrap

Vault initialization and Kubernetes auth setup remain human-gated.

**Requires cluster access:**

1. Initialize and unseal Vault.
2. Enable the Kubernetes auth method in Vault.
3. Configure `auth/kubernetes/config` for the cluster API.
4. Create a Vault policy that grants ESO read access to the target KV paths.
5. Create a Vault role named `external-secrets` bound to service account `vault-reader` in namespace `platform`.
6. Write the first secrets to the KV v2 paths listed above.

HashiCorp documents the Kubernetes auth flow at:

- https://developer.hashicorp.com/vault/docs/auth/kubernetes

Big Bang documents Vault Kubernetes integration and notes that `autoInit` can configure this automatically only when auto-init is enabled:

- https://docs-bigbang.dso.mil/3.16.0/packages/vault/docs/bigbang-operational-guide/

External Secrets Operator documents Vault-backed stores and `ClusterSecretStore` auth requirements at:

- https://external-secrets.io/v2.0.0/provider/hashicorp-vault/

## Next GitOps Changes

After the initial migration set:

1. remove or archive superseded `SealedSecret` manifests that are no longer authoritative
2. review whether any remaining platform or tenant secrets should move to Vault now
3. document the final steady-state secret-management model for this environment

## Current Recommendation

Treat the initial Vault-backed migration wave as complete.

Recommended next steps:

1. clean up superseded `SealedSecret` references and files
2. keep issue `#54` open until lifecycle, recovery, and environment-semantics documentation is fully settled
3. decide whether additional secrets should migrate now or whether this is a sufficient stopping point for the current phase
