# Vault Hardening Plan

Status: open

Related issues:

- `gitops#54` Harden Vault persistence and lifecycle behavior for the current environment
- `gitops#55` Rename the current environment and introduce a true local sandbox

## Purpose

This document captures the concrete hardening work needed before Vault should be treated as a trusted secret source for broader migration in the current environment.

It is intentionally environment-specific and belongs in `gitops`, not `platform-docs`.

## Why This Exists

Recent recovery work established that:

- Vault can be deployed via Big Bang in the current environment
- External Secrets Operator can be installed and wired structurally to Vault
- Vault can advertise the correct in-cluster API address

However, namespace/release churn also produced a fresh Vault instance that returned:

- `Initialized: false`

At the time of inspection:

- the current PVCs were newly created on 2026-03-17
- `/vault/data` was mounted but empty
- old unseal keys were no longer applicable

That means the current environment can recreate Vault, but continuity of Vault state is not yet trustworthy enough for broader migration.

## Current Findings

The following findings are already established from direct cluster inspection in the current environment:

### 1. Vault continuity was lost during recovery/reconciliation churn

Observed sequence:

- Vault was previously observed in an initialized state
- later, `vault operator unseal` failed with `Vault is not initialized`
- `vault status` then confirmed `Initialized: false`

Implication:

- the live Vault instance was no longer the previously initialized instance
- prior unseal keys were not usable against the new instance

### 2. The current Vault instance is using newly created storage objects

Observed state:

- `vault-vault` StatefulSet creation timestamp: 2026-03-17 18:52:10 UTC
- PVC `data-vault-vault-0` was bound and in use by `vault-vault-0`
- PVC `audit-vault-vault-0` was bound and in use by `vault-vault-0`

Implication:

- the currently running Vault pod is attached to a fresh storage lifecycle relative to the earlier initialized instance

### 3. Vault storage is mounted, but the active data path was empty

Observed state:

- `/vault/data` was mounted read-write from the `data` PVC
- `ls -la /vault/data` showed an empty directory

Implication:

- this is not a case of Vault simply missing a mount at runtime
- the mounted storage backing the current pod did not contain a previously initialized Vault state

### 4. The deployment is persistent in shape, but not yet trusted in lifecycle behavior

Observed state:

- Vault is deployed as a StatefulSet
- storage class is `local-path`
- data and audit PVCs are both present and mounted
- StatefulSet update strategy is `OnDelete`

Implication:

- the deployment shape looks persistent
- the operational problem is lifecycle continuity across rebuild/churn, not the absence of PVCs in the current pod

### 5. The environment behaves like persistent on-prem infrastructure, not a disposable sandbox

Operational conclusion:

- stateful platform services exist here
- durability assumptions matter
- namespace/release churn can have consequences that are too expensive to wave away as sandbox breakage

Implication:

- Vault hardening should be treated as persistent-environment platform work
- broader secret migration should remain paused until this model is understood

## Current Decision

Broader secret migration is paused until the persistence and lifecycle model is understood.

Allowed for now:

- platform hardening work
- documentation
- low-risk validation planning

Not recommended for now:

- migrating shared credentials to Vault
- treating the current environment as a disposable sandbox
- assuming Vault state survives all current reconciliation or rebuild paths

## Investigation Questions

Answer these first:

1. What exact sequence caused the previously initialized Vault instance to be replaced by a fresh uninitialized instance?
2. Were the old Vault PVCs deleted, rebound, or replaced during namespace/release churn?
3. What is the reclaim behavior of the current `local-path` storage class in this environment?
4. Is `local-path` acceptable for Vault in the current long-lived environment?
5. What lifecycle actions are safe, and which should be treated as destructive?
6. What backup/recovery expectations should apply to Vault here?

## Evidence To Collect

Collect and preserve evidence for the current environment:

- StatefulSet lifecycle behavior for `vault-vault`
- PVC and PV metadata before and after any controlled restart/reconciliation
- storage class behavior and reclaim policy
- whether namespace deletion destroys Vault continuity in practice
- whether pod restart without namespace/release churn preserves initialization state

Suggested evidence commands:

**Run manually by human**

```bash
kubectl -n vault get statefulset vault-vault -o yaml
kubectl -n vault get pvc,pv
kubectl get storageclass local-path -o yaml
kubectl -n vault get pod vault-vault-0 -o yaml
kubectl -n vault exec -it vault-vault-0 -- sh -c 'ls -la /vault/data'
```

## Hardening Work

### 1. Document current lifecycle semantics

- Record which actions are non-destructive:
  - pod restart
  - node restart
  - Flux reconcile
- Record which actions are destructive or currently suspected to be destructive:
  - namespace deletion
  - release uninstall/reinstall
  - PVC recreation or rebinding

### 2. Verify persistence under controlled conditions

- Reinitialize Vault only if needed for a controlled persistence test
- Test whether initialization survives:
  - pod deletion
  - StatefulSet restart
  - node restart
- Do not repeat namespace or release churn without first deciding whether that is an accepted destructive path

### 3. Decide whether the current storage model is acceptable

- If `local-path` is acceptable for this environment, document the constraints clearly
- If not, define the replacement storage/backend plan

### 4. Define recovery expectations

- Decide whether Vault in this environment requires backup before any destructive operations
- Decide whether a lost Vault should be:
  - restored
  - reinitialized and repopulated
  - treated as an incident requiring manual operator steps

## Exit Criteria

This issue is complete when:

- the current environment has a documented Vault persistence model
- destructive vs non-destructive lifecycle actions are explicit
- the storage choice is either accepted with constraints or flagged for replacement
- recovery expectations are written down
- the team can make a clear go/no-go decision on broader Vault migration

## Follow-on Actions

After this hardening work:

- revisit `docs/vault-migration-plan.md`
- decide whether `mia-provider` remains the only test path or broader migration can resume
- align the current environment name with its actual lifecycle semantics
