# GHCR Auth via Sealed Secrets

This runbook captures how to manage GHCR credentials in GitOps using Sealed Secrets.

Two consumers need registry auth:

- `mia` namespace (`imagePullSecrets`) for kubelet image pulls
- `kyverno` namespace (`verifyImages`) for Kyverno signature/attestation lookups

## Prerequisites

- `kubectl` with cluster access
- `kubeseal` installed
- `zavestudios-bot` PAT with `read:packages`

## 1) Create a SealedSecret for `mia` image pulls

**Run manually by human:**

```bash
kubectl create secret docker-registry ghcr-secret \
  --namespace mia \
  --docker-server=ghcr.io \
  --docker-username=zavestudios-bot \
  --docker-password='<PAT_WITH_read:packages>' \
  --dry-run=client -o yaml \
| kubeseal --format yaml \
> tenants/mia/ghcr-secret.sealed.yaml
```

Then include it in `tenants/mia/kustomization.yaml`:

```yaml
resources:
  - ghcr-secret.sealed.yaml
```

## 2) Create a SealedSecret for Kyverno verification

**Run manually by human:**

```bash
kubectl create secret docker-registry ghcr-secret \
  --namespace kyverno \
  --docker-server=ghcr.io \
  --docker-username=zavestudios-bot \
  --docker-password='<PAT_WITH_read:packages>' \
  --dry-run=client -o yaml \
| kubeseal --format yaml \
> platform/policies/kyverno/ghcr-secret.sealed.yaml
```

Then include it in `platform/policies/kyverno/kustomization.yaml`:

```yaml
resources:
  - ghcr-secret.sealed.yaml
```

## 3) Verify policy wiring

`platform/policies/kyverno/require-signed-ghcr-images.yaml` should include:

- `imageRegistryCredentials.helpers: [github]`
- `imageRegistryCredentials.secrets: [ghcr-secret]`

## 4) Reconcile and validate

After merge and reconciliation:

- Kyverno `require-signed-ghcr-images` should stop reporting GHCR `UNAUTHORIZED`.
- `mia` pod pulls should continue using `imagePullSecrets: [ghcr-secret]`.
