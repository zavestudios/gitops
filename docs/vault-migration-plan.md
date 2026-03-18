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

The repository currently stores secrets with `SealedSecret` resources:

- `platform/cloudflare/sealed-secret.yaml`
- `platform/policies/kyverno/ghcr-secret.sealed.yaml`
- `tenants/mia/ghcr-secret.sealed.yaml`

The first workload secret has already been migrated to an `ExternalSecret`:

- `tenants/mia/mia-provider.external-secret.yaml`

Vault is already enabled in `bigbang/values.yaml`.

This change adds:

- Big Bang `externalSecrets` addon enabled
- A GitOps-managed `ClusterSecretStore` pointing at in-cluster Vault
- A dedicated `vault-reader` service account for ESO Vault authentication
- ordered Flux reconciliation across `platform/core`, `bigbang`, and `platform/runtime`

## Current Decision

Broader Vault migration is intentionally paused.

Reason:

- The current environment behaved as a long-lived, stateful platform environment rather than a disposable sandbox.
- During namespace/release churn, Vault returned to `Initialized: false`, which showed that continuity of Vault state is not yet operationally trustworthy for broader migration.
- External Secrets integration is now structurally in place, but platform hardening should happen before additional secrets move to Vault.

Tracked follow-up work:

- `gitops#54` Harden Vault persistence and lifecycle behavior for the current environment
- `gitops#55` Rename the current environment and introduce a true local sandbox

## Constrained Proof Path Status

The constrained proof path for `mia-provider` has now succeeded.

What was validated:

- Vault was initialized, unsealed, and configured for Kubernetes auth
- External Secrets Operator authenticated to Vault through the `vault-kv` `ClusterSecretStore`
- the `mia-provider` `ExternalSecret` synced successfully
- Kubernetes secret `mia-provider` was created in namespace `mia`

What this means:

- the Vault and External Secrets functional integration path is now proven for a low-risk tenant secret
- the remaining blocker to broader migration is lifecycle and durability confidence, not basic integration viability

## Migration Order

Migration order:

1. `mia-provider` (implemented in GitOps as the initial target path)
2. `cloudflared-token`
3. GHCR pull secrets (`platform/policies/kyverno/ghcr-secret`, `tenants/mia/ghcr-secret`)

Why this order:

- `mia-provider` is a straightforward single-key opaque secret.
- `cloudflared-token` is also a single-key opaque secret and easy to validate.
- GHCR pull secrets are shared operational credentials and should move only after the Vault and ESO path is proven stable.

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

**Run manually by human**

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

## Next GitOps Changes After Bootstrap

After Vault is initialized and populated:

1. Validate `mia` reads the synced `mia-provider` Kubernetes secret successfully.
2. Replace `platform/cloudflare/sealed-secret.yaml` with an `ExternalSecret`.
3. Replace the GHCR `SealedSecret` resources with `ExternalSecret` resources.
4. Remove Sealed Secrets only after each replacement is verified.

## Current Recommendation

Do not continue broader secret migration until issue `#54` is addressed.

If a minimal proof path is needed before that hardening work completes, limit it to a single low-risk secret and treat it as validation work, not as the start of broad cutover.
