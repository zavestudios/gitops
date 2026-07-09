# ArgoCD Keycloak SSO Runbook

## Status

GitOps config added for `zavestudios/gitops#90`.

Runtime verification still requires cluster access.

## Authority

Flux manages the Big Bang foundation release that installs ArgoCD and Keycloak.
ArgoCD does not manage itself.

The ArgoCD SSO model is declared in:

- `bigbang/foundation/values-foundation.yaml`
- `platform/argocd/external-secrets.yaml`

## Normal Login

Use:

```text
https://argocd-on-prem.zavestudios.com
```

Select the Keycloak SSO login option.

Expected identity provider:

```text
https://sso-on-prem.zavestudios.com/auth/realms/zavestudios
```

## Role Mapping

ArgoCD RBAC maps Keycloak groups as follows:

```text
zave-platform-admins     -> role:admin
zave-platform-operators  -> role:readonly
```

The Keycloak `argocd` client must emit a group claim compatible with the Big
Bang ArgoCD SSO client scope.

## Secret Source

The ArgoCD OIDC client secret is sourced from Vault through External Secrets:

```text
Vault path:        platform/services/argocd/oidc
Vault property:    clientSecret
Kubernetes Secret: argocd/argocd-keycloak-oidc
ArgoCD reference:  $argocd-keycloak-oidc:clientSecret
```

Do not commit the client secret to Git.

## Verification

**Requires cluster access:**

```bash
kubectl -n argocd get externalsecret argocd-keycloak-oidc
kubectl -n argocd get secret argocd-keycloak-oidc \
  -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}{"\n"}'
kubectl -n argocd get configmap argocd-cm -o yaml
kubectl -n argocd get configmap argocd-rbac-cm -o yaml
kubectl -n bigbang get helmrelease bigbang-foundation
```

Confirm:

- `argocd-keycloak-oidc` is synced and labeled `app.kubernetes.io/part-of=argocd`.
- `argocd-cm` contains `oidc.config` with the Keycloak issuer.
- `argocd-rbac-cm` contains the expected group mappings.
- Keycloak login succeeds for an admin user.
- Keycloak login succeeds for a read-only/operator user.
- Login still works after an `argocd-server` pod restart.

## Break-Glass Local Admin

Local admin remains a break-glass path until Keycloak SSO is verified.

Use it only for recovery when SSO or Keycloak is unavailable. Any manual runtime
action must be backported into Git or documented as incident follow-up.

**Requires cluster access:**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret
kubectl -n argocd get secret argocd-secret
```

If a password reset is required, capture the command and reason in the incident
notes before closing the incident.

## Rollback

Rollback is Git-first:

1. Revert the `addons.argocd.sso` block in `bigbang/foundation/values-foundation.yaml`.
2. Revert `argocd-keycloak-oidc` from `platform/argocd/external-secrets.yaml` if it is not needed.
3. Merge through PR and allow Flux to reconcile.

**Requires cluster access:**

```bash
flux reconcile kustomization on-prem-bigbang-foundation -n flux-system
kubectl -n bigbang get helmrelease bigbang-foundation
kubectl -n argocd get configmap argocd-cm -o yaml
```

Do not remove or disable local admin as part of the initial SSO rollout.
