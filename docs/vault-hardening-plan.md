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

## Candidate Causes To Validate

These are hypotheses, not confirmed root causes.

### 1. Namespace or release churn replaced the prior Vault lifecycle

Why it is plausible:

- the environment went through namespace/release churn during reconciliation recovery
- the currently running Vault StatefulSet and PVC objects are newer than the earlier initialized state that had been observed

What to validate:

- whether the old Vault namespace/PVC lifecycle was deleted and recreated
- whether Big Bang or Flux remediation paths severed continuity from the earlier initialized instance

### 2. `local-path` storage continuity was affected by node or hypervisor lifecycle

Why it is plausible:

- Vault storage is node-local through `local-path`
- the PVCs were selected onto `k3s-cp-01`
- hypervisor/node lifecycle can affect assumptions about local-path-backed state

What to validate:

- whether a hypervisor upgrade/reboot or node restart occurred in the same time window
- whether other `local-path` workloads on that node retained continuity
- whether the underlying local-path storage directory persisted as expected

### 3. The current environment naming encouraged destructive assumptions

Why it is plausible:

- the current cluster is named `sandbox`
- recent events showed it behaves like a persistent environment with meaningful state

What to validate:

- whether sandbox naming contributed to tolerating destructive lifecycle actions that would not be acceptable in a persistent environment

### 4. The current Vault storage model may be acceptable only with stricter operational constraints

Why it is plausible:

- the current deployment shape is a single-node StatefulSet with `storage "file"`
- this may be acceptable for a constrained environment, but only if destructive operations are explicitly understood and avoided

What to validate:

- whether the real issue is storage unsuitability, or simply the absence of clearly documented destructive boundaries

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

## Lifecycle Classification

Current working classification for the current environment:

| Action | Current Classification | Reason |
| --- | --- | --- |
| Flux reconcile with no destructive drift | Expected non-destructive, still validate | This should not replace Vault state, but evidence should still be captured. |
| Pod restart | Unknown, validate | Persistence should survive this if PVC continuity is real. |
| StatefulSet restart / pod recreation | Unknown, validate | This is a key durability check for the mounted PVC-backed state. |
| Node restart on the selected node | Unknown, validate | `local-path` behavior under node lifecycle should be confirmed explicitly. |
| Helm upgrade with retained namespace and PVCs | Unknown, validate | Should be safe in principle, but current evidence is not strong enough yet. |
| Namespace deletion | Destructive or presumed destructive | Recent churn led to a fresh uninitialized Vault instance. |
| Release uninstall / reinstall | Destructive or presumed destructive | Current evidence suggests this can sever continuity from the prior Vault instance. |
| PVC deletion or rebinding to fresh storage | Destructive | This necessarily breaks Vault continuity for `storage \"file\"`. |

Operational rule for now:

- Treat namespace deletion, release uninstall/reinstall, and PVC recreation as destructive operations for Vault in the current environment.
- Do not migrate broader secrets until the currently unknown actions are validated and documented.

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

## Observed Environment Facts

The following environment facts are now confirmed:

- `local-path` reclaim policy is `Delete`
- `local-path` volume binding mode is `WaitForFirstConsumer`
- Vault data PVC and audit PVC are both bound with `StorageClass: local-path`
- The current Vault PVCs are approximately one day old relative to the current investigation window
- The current Vault pod is scheduled on node `k3s-cp-01`
- Vault StatefulSet update strategy is `OnDelete`
- `/vault/data` was observed empty after churn before reinitialization
- after controlled reinitialization and pod recreation testing, `/vault/data` contained persistent Vault state directories (`core`, `logical`, `sys`)

Implications:

- the current storage class is node-local and destructive PVC lifecycle needs to be treated seriously
- PVC recreation is a particularly important continuity boundary because reclaim policy is `Delete`
- continuity testing should focus on non-destructive restart paths first, before any intentionally destructive actions are repeated

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

## Validation Procedures

Start with the least destructive checks first.

### Validation 1: Pod Restart Continuity

Purpose:

- verify whether the current Vault state survives a basic pod recreation while retaining the same PVC-backed storage

Preconditions:

- Vault has been intentionally initialized for the test window
- current unseal keys and root token are stored safely
- no broader secret migration depends on this validation succeeding

Procedure:

**Run manually by human**

```bash
kubectl -n vault exec -it vault-vault-0 -- vault status
kubectl -n vault get pod vault-vault-0 -o wide
kubectl -n vault get pvc data-vault-vault-0 audit-vault-vault-0
kubectl -n vault delete pod vault-vault-0
kubectl -n vault get pod vault-vault-0 -w
kubectl -n vault exec -it vault-vault-0 -- vault status
kubectl -n vault exec -it vault-vault-0 -- sh -c 'ls -la /vault/data'
```

Success criteria:

- the recreated pod returns with the same PVCs attached
- `vault status` still reports `Initialized: true`
- Vault does not come back as a fresh uninitialized instance
- `/vault/data` contains persistent state rather than appearing newly empty

Failure criteria:

- `vault status` returns `Initialized: false`
- the pod binds to fresh PVCs or otherwise loses continuity with the prior storage state
- the storage directory appears freshly empty despite the restart being non-destructive in intent

Interpretation:

- If this test fails, the current storage/lifecycle model is not trustworthy even for basic pod-level recovery.
- If this test passes, continue to the next least-destructive validation rather than jumping immediately to more disruptive lifecycle actions.

Result:

- Passed

Observed outcome:

- after controlled initialization and unseal, pod recreation preserved Vault state on the existing PVC-backed storage
- after pod recreation, `vault status` reported `Initialized: true` and `Sealed: true`
- manual unseal was still required after restart
- `/vault/data` retained persistent state directories rather than returning as a fresh empty path

Conclusion:

- basic pod-level continuity is working in the current environment
- the remaining hardening concern is broader lifecycle durability and operational recovery behavior, not immediate loss of state on simple pod recreation

### Validation 2: Node Restart Continuity

Purpose:

- verify whether the current Vault state survives a restart of the node hosting the active Vault pod and its `local-path`-backed PVCs

Preconditions:

- Vault has been initialized and unsealed for the validation window
- the active Vault pod is scheduled on `k3s-cp-01`
- current unseal keys are available for manual recovery after restart

Procedure:

**Run manually by human**

```bash
kubectl -n vault get pod vault-vault-0 -o wide
kubectl -n vault exec -it vault-vault-0 -- vault status
kubectl -n vault exec -it vault-vault-0 -- sh -c 'ls -la /vault/data'
# Restart the underlying node or VM hosting k3s-cp-01
kubectl get nodes
kubectl -n vault get pod vault-vault-0 -o wide
kubectl -n vault exec -it vault-vault-0 -- vault status
kubectl -n vault exec -it vault-vault-0 -- sh -c 'ls -la /vault/data'
kubectl get clustersecretstore vault-kv
kubectl -n mia get secret mia-provider
```

Success criteria:

- the Vault pod returns on `k3s-cp-01` with the same persistent state intact
- `vault status` reports `Initialized: true` after node recovery
- `/vault/data` still contains persisted Vault state
- `vault-kv` returns to `Valid` after manual unseal
- `mia-provider` remains present in namespace `mia`

Failure criteria:

- Vault returns as `Initialized: false`
- the data path appears freshly empty
- the `ClusterSecretStore` cannot recover after manual unseal
- the synced tenant secret is lost unexpectedly

Result:

- Passed for continuity

Observed outcome:

- after node reboot, Vault returned as `Initialized: true` and `Sealed: true`
- `/vault/data` retained persistent state directories including `auth`, `core`, `logical`, and `sys`
- `mia-provider` remained present in namespace `mia`
- `vault-kv` returned to `Valid` after Vault was manually unsealed

Conclusion:

- node restart continuity is working for the current `local-path`-backed Vault deployment on `k3s-cp-01`
- the remaining operational gap is that Vault does not automatically return to service after restart because manual unseal is still required

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

## Availability Decision

Current state:

- continuity has now been validated for both pod restart and node restart on `k3s-cp-01`
- AWS KMS auto-unseal has been implemented successfully
- Vault now returns to service after restart without manual unseal
- `vault-kv` returns to `Valid` after restart without operator unseal steps

This means the primary remaining hardening work is documenting the new recovery model clearly and deciding how quickly to expand migration scope.

## Current Recovery Model

Current operator recovery flow after routine restart:

**Run manually by human**

```bash
kubectl -n vault exec -it vault-vault-0 -- vault status
kubectl get clustersecretstore vault-kv
```

Expected result:

- `vault status` returns `Initialized: true` and `Sealed: false`
- `Seal Type` remains `awskms`
- `vault-kv` returns to `Valid` without manual unseal

## Decision Status

Availability decision:

- completed

Outcome:

- AWS KMS auto-unseal is the accepted recovery model for the current on-prem environment
- manual unseal is no longer the steady-state restart recovery path
- broader Vault-backed migration no longer needs to remain limited to a single constrained proof path on availability grounds

## Next Investigation

The next hardening investigation should answer:

1. how AWS credentials for auto-unseal should evolve from the current bootstrap model to a cleaner long-term identity model
2. what staged migration order should be used for the remaining shared and tenant secrets
3. what additional recovery checks should be documented for node, pod, and package restart events
