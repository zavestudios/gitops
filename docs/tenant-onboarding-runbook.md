# Tenant Onboarding Runbook

**Status:** Active  
**Updated:** 2026-03-24

## Purpose

Document the operator-facing sequence for onboarding a tenant workload into the cluster without relying on ad hoc memory.

This runbook is intentionally practical. It captures:
- the order of operations
- the cross-repo prerequisites
- the common failure modes observed during `oracle` and `panchito` onboarding

This document is the operational companion to the platform doctrine in `platform-docs/_platform/`.

## Scope

This runbook covers:
- tenant repo CI/CD readiness
- GitOps registration
- Vault and External Secrets prerequisites
- shared dependency prerequisites
- deployment validation

This runbook does **not** redefine:
- contract schema
- repo taxonomy
- control-plane authority

Those remain authoritative in `platform-docs/_platform/`.

## Owning Repositories

Per `REPO_TAXONOMY.md`, tenant onboarding usually touches:

- tenant repo
  - workload code
  - `zave.yaml`
  - shared CI/CD workflow usage
- `gitops`
  - tenant manifests
  - ArgoCD registration
  - ExternalSecret objects
- `kubernetes-platform-infrastructure`
  - external VM substrate for shared dependencies
- `pg`
  - PostgreSQL tenant provisioning
- Vault
  - tenant and platform secret material

## Standard Sequence

### 1. Validate tenant repo readiness

Confirm the tenant repo has:
- valid `zave.yaml`
- build/publish workflow
- CI-to-GitOps promotion path if the tenant is intended to auto-promote images

Examples:
- `mia`
- `oracle`
- `panchito`

### 2. Confirm dependency model

Do **not** onboard the runtime until its real dependencies exist.

Examples:
- `oracle` used a bounded in-cluster PostgreSQL exception
- `panchito` waited for shared PostgreSQL and shared Redis VMs

If dependencies do not exist yet:
- finish tenant CI/CD normalization
- stop short of claiming runtime readiness

### 3. Create platform/shared dependencies first

Examples:
- shared PostgreSQL VM in `kubernetes-platform-infrastructure`
- shared Redis VM in `kubernetes-platform-infrastructure`
- tenant DB/role provisioning in `pg`

Do not invent tenant-local copies of shared services unless explicitly accepted as a bounded exception.

### 4. Populate Vault paths

Typical paths:

Platform-owned:
- `platform/storage/pg/admin`

Tenant-owned:
- `tenants/<tenant>/ghcr`
- `tenants/<tenant>/app`
- `tenants/<tenant>/db`
- optionally later `tenants/<tenant>/redis`

Examples:

`tenants/panchito/app`
- `SECRET_KEY`
- `CELERY_BROKER_URL`
- `CELERY_RESULT_BACKEND`
- `LOG_LEVEL`

`tenants/panchito/db`
- `DATABASE_URL`
- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`

### 5. Update Vault policy for ESO

Creating secrets in Vault is not enough.

The External Secrets Operator must also be authorized to read the tenant paths.

Typical policy shape:

```hcl
path "secret/data/tenants/<tenant>/*" {
  capabilities = ["read"]
}

path "secret/metadata/tenants/<tenant>/*" {
  capabilities = ["read"]
}
```

This step was required for both:
- `oracle`
- `panchito`

### 6. Merge GitOps tenant manifests

Expected pieces:
- tenant namespace
- `ghcr` ExternalSecret
- tenant app ExternalSecret
- tenant DB ExternalSecret if needed
- `Deployment`
- `Service`
- ArgoCD `Application`

### 6A. First image promotion sequencing

For a brand-new tenant, the first successful application image build may complete
before the GitOps digest-promotion workflow exists on `gitops` `main`.

If that happens:
- the tenant may still be registered with a bootstrap or placeholder image reference
- the `repository_dispatch` from the tenant repo will not retroactively replay
- ArgoCD may reconcile successfully while the workload still fails with `ErrImagePull`

Recovery path:
- confirm the tenant repo `main` build succeeded
- patch the deployment image to the published `sha-<commit>` tag or trigger the GitOps workflow manually
- after the first promotion lands on `main`, subsequent `repository_dispatch` events should use the normal digest update path

### 7. Reconcile and observe

Use ArgoCD and Kubernetes status to determine the **current** blocker, not stale historical assumptions.

## Validation Checklist

### Secrets

**Run manually by human**

```bash
kubectl -n <tenant> get externalsecret
kubectl -n <tenant> describe externalsecret <name>
kubectl -n <tenant> get secret
```

Expected:
- ExternalSecrets show successful sync
- target secrets exist in the tenant namespace

### Pods

**Run manually by human**

```bash
kubectl -n <tenant> get pods
kubectl -n <tenant> describe pod -l app=<tenant>
kubectl -n <tenant> logs deploy/<tenant> --tail=200
```

Expected:
- images pull successfully
- container starts
- probes become healthy

### Database connectivity

For DB-backed tenants, validate from inside the pod when needed.

**Run manually by human**

```bash
kubectl -n <tenant> exec -it deploy/<tenant> -- sh -lc 'python - <<'"'"'PY'"'"'
import os
import psycopg2
dsn = "dbname={db} user={user} password={pw} host={host} port={port}".format(
    db=os.environ["DB_NAME"],
    user=os.environ["DB_USER"],
    pw=os.environ["DB_PASSWORD"],
    host=os.environ["DB_HOST"],
    port=os.environ["DB_PORT"],
)
conn = psycopg2.connect(dsn)
cur = conn.cursor()
cur.execute("select 1")
print(cur.fetchone())
conn.close()
PY'
```

## Common Failure Modes

### 1. Vault path exists, but namespace secret does not

Likely cause:
- ESO policy is missing tenant path permission

Signal:
- `ExternalSecret` shows Vault `403 permission denied`

Observed in:
- `oracle`
- `panchito`

### 2. Job exists in Git, but Argo cannot update it

Likely cause:
- immutable `Job.spec.template` drift

Signal:
- Argo sync error
- `field is immutable`

Fix:
- delete the existing Job object
- let Argo recreate it from the corrected manifest

Observed in:
- `oracle-migrations`

### 3. Pod is `Running` but not `Ready`

Likely causes:
- readiness probe is checking a real dependency
- app starts, but dependency-specific check fails

Observed in:
- `panchito` readiness was DB-backed and exposed a PostgreSQL role connection-limit issue

### 4. Shared DB connectivity works, but role hits connection cap

Likely cause:
- platform default too strict for app process model

Observed in:
- `panchito_app`

Fix:
- raise the tenant role connection limit
- capture the default mismatch as a `pg` follow-up

### 5. Image pull failures despite GitOps correctness

Likely causes:
- namespace `ghcr-secret` missing
- bad Vault data at `tenants/<tenant>/ghcr`
- ESO policy missing for `ghcr` path
- stale or non-existent image tag

### 6. Signed-image warnings

Differentiate:
- background scan warning
- admission denial

Only admission denial blocks creation immediately.

## Tenant-Specific Notes So Far

### `oracle`

- bounded exception: in-cluster PostgreSQL
- required:
  - migration job
  - worker init container waiting for schema
  - Vault policy updates for tenant secret paths
  - CI-to-GitOps image promotion fix

### `panchito`

- shared dependency model:
  - external shared PostgreSQL VM
  - external shared Redis VM
- required:
  - tenant DB provisioning through `pg`
  - separate `app` and `db` secret paths
  - Vault policy updates for tenant secret paths

## When To Stop And Fix The Platform

Stop tenant onboarding and switch back to platform work when:
- the tenant lacks a real dependency path
- CI publishes images but GitOps cannot consume them automatically
- Vault/ESO policy patterns are still ad hoc
- the same failure has happened for more than one tenant

That is a platform problem, not a tenant-specific problem.
