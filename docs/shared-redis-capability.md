# Shared Redis Capability

**Status:** Active
**Updated:** 2026-04-03

## Purpose

Document the platform-owned Redis capability for tenant workloads that need broker/cache semantics.

This is the operational companion to the shared PostgreSQL capability documented in `pg/docs/PROVISIONING.md`.

## Runtime Model

### Infrastructure Ownership

| Layer | Owner | Location |
|-------|-------|----------|
| VM provisioning | `kubernetes-platform-infrastructure` | `terraform-libvirt/` |
| Redis installation | cloud-init | `cloud-init/redis.yml.tpl` |
| Tenant secret delivery | `gitops` + Vault | ExternalSecrets |

### Current Deployment

- **Host:** `redis-01`
- **IP:** `192.168.122.21`
- **Port:** `6379`
- **Persistence:** AOF enabled (`appendonly yes`)
- **Binding:** Internal subnet only (`127.0.0.1` + VM IP)
- **Auth:** None (protected-mode, internal network only)

### What This Capability Provides

- Shared in-cluster-reachable Redis for broker/cache use cases
- Platform-owned lifecycle (not tenant-managed)
- Vault-delivered credentials for tenant consumption

### What This Capability Does Not Provide

- Multi-tenant isolation (all tenants share the same Redis instance)
- Per-tenant authentication
- Data persistence guarantees beyond AOF
- High availability or clustering

## Tenant Consumption Contract

### Vault Secret Path

Tenant Redis configuration is stored at:

```
tenants/<tenant>/app
```

### Required Keys

For Celery-style workloads (e.g., `panchito`):

| Key | Description | Example |
|-----|-------------|---------|
| `CELERY_BROKER_URL` | Celery broker connection string | `redis://192.168.122.21:6379/0` |
| `CELERY_RESULT_BACKEND` | Celery result backend connection string | `redis://192.168.122.21:6379/1` |

For Rails-style workloads (e.g., `rigoberta`):

| Key | Description | Example |
|-----|-------------|---------|
| `REDIS_URL` | Generic Redis connection string | `redis://192.168.122.21:6379/1` |

### Database Number Convention

Use separate Redis databases per tenant to provide logical separation:

| Tenant | Broker DB | Result/Cache DB |
|--------|-----------|-----------------|
| panchito | 0 | 1 |
| rigoberta | 1 | - |
| thehouseguy | 2 | 3 |

This is a soft convention, not enforced isolation.

## Provisioning Workflow

### 1. Ensure Redis VM exists

The Redis VM is provisioned by `kubernetes-platform-infrastructure`:

```bash
cd /path/to/kubernetes-platform-infrastructure/terraform-libvirt
terraform apply -var="redis_enabled=true"
```

Verify:

```bash
ssh ubuntu@192.168.122.21 "redis-cli ping"
# Expected: PONG
```

### 2. Populate Vault secrets

For a new tenant, add the Redis configuration to the tenant's app secrets:

```bash
vault kv put secret/tenants/<tenant>/app \
  CELERY_BROKER_URL="redis://192.168.122.21:6379/<broker_db>" \
  CELERY_RESULT_BACKEND="redis://192.168.122.21:6379/<result_db>" \
  # ... other app secrets
```

Or for Rails-style:

```bash
vault kv put secret/tenants/<tenant>/app \
  REDIS_URL="redis://192.168.122.21:6379/<db>" \
  # ... other app secrets
```

### 3. Update Vault policy for ESO

Ensure the External Secrets Operator can read the tenant path:

```hcl
path "secret/data/tenants/<tenant>/*" {
  capabilities = ["read"]
}

path "secret/metadata/tenants/<tenant>/*" {
  capabilities = ["read"]
}
```

### 4. Create GitOps ExternalSecret

Example for `panchito`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: panchito-app
  namespace: panchito
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: vault-kv
  target:
    name: panchito-app
    creationPolicy: Owner
  data:
    - secretKey: CELERY_BROKER_URL
      remoteRef:
        key: tenants/panchito/app
        property: CELERY_BROKER_URL
    - secretKey: CELERY_RESULT_BACKEND
      remoteRef:
        key: tenants/panchito/app
        property: CELERY_RESULT_BACKEND
```

## Validation Procedure

### 1. Verify Redis VM is healthy

**Requires cluster access:**

```bash
ssh ubuntu@192.168.122.21 "redis-cli ping"
# Expected: PONG

ssh ubuntu@192.168.122.21 "redis-cli info server | head -10"
```

### 2. Verify tenant secrets sync

**Requires cluster access:**

```bash
kubectl -n <tenant> get externalsecret
kubectl -n <tenant> describe externalsecret <tenant>-app
```

Expected: `SecretSynced` condition is `True`.

### 3. Verify tenant can connect

**Requires cluster access:**

For Python/Celery workloads:

```bash
kubectl -n <tenant> exec -it deploy/<tenant> -- python -c "
import os
import redis
r = redis.from_url(os.environ['CELERY_BROKER_URL'])
print(r.ping())
"
```

For Rails workloads:

```bash
kubectl -n <tenant> exec -it deploy/<tenant> -- rails runner "
require 'redis'
r = Redis.new(url: ENV['REDIS_URL'])
puts r.ping
"
```

### 4. Verify tenant workload health

**Requires cluster access:**

```bash
kubectl -n <tenant> get pods
kubectl -n <tenant> logs deploy/<tenant> --tail=50 | grep -i redis
```

## Current Consumers

| Tenant | Use Case | Status |
|--------|----------|--------|
| panchito | Celery broker + result backend | Manifests ready |
| rigoberta | Rails cache/sessions | Deployed and healthy |
| thehouseguy | TBD | Not yet onboarded |

## Limitations and Future Work

### Current Limitations

1. **No authentication:** Redis is open on the internal network
2. **No isolation:** All tenants share the same Redis instance
3. **Single node:** No HA or clustering
4. **Manual provisioning:** No automated tenant onboarding

### Potential Improvements

1. Add Redis AUTH password (stored in Vault, injected to connection strings)
2. Consider Redis ACLs for per-tenant users (Redis 6+)
3. Add Redis Sentinel or Cluster for HA if needed
4. Automate tenant database assignment

These are not blockers for current Formation phase goals.

## Related Documentation

- `pg/docs/PROVISIONING.md` - PostgreSQL tenant provisioning
- `gitops/docs/tenant-onboarding-runbook.md` - Full tenant onboarding sequence
- `kubernetes-platform-infrastructure/terraform-libvirt/cloud-init/redis.yml.tpl` - Redis VM cloud-init
