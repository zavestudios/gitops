# Platform Stability Gap Analysis

**Current as of:** 2026-06-21

**Status:** Active stability baseline and gap analysis

**Purpose:** Define the current repository-backed stability baseline, record
which post-incident gaps are closed, and prioritize the remaining work required
before broad platform expansion resumes.

## Current Conclusion

The platform has moved out of incident follow-through and into controlled
stabilization.

The repository-level control-plane graph is legible and the post-`#240`
architecture decisions are complete. The current Big Bang split is an accepted
operational baseline, but it is not the desired steady-state ownership model.
Direct Flux package ownership is the accepted target, beginning with the
inventory in `#300`.

The platform should therefore be described as:

- **operationally recovered** based on the latest recorded controller evidence
- **repository-stable enough for deliberate app and architecture work**
- **architecturally transitional** while Big Bang remains the package lifecycle
  intermediary
- **not runtime-verified by this analysis**, because current cluster evidence
  requires a human operator with cluster access

The stability pause remains active. Package extraction is stability work when
it follows the accepted boundary strategy; unrelated capability expansion is
not.

## Evidence Boundary

This document distinguishes four evidence classes:

1. **Repository truth:** manifests, dependencies, contracts, and accepted
   decisions present in Git.
2. **Rendered truth:** Kustomize and Helm output derived from repository state.
3. **Controller truth:** Flux, HelmRelease, ArgoCD, and External Secrets status.
4. **Runtime truth:** live workloads, storage, webhooks, ingress, authentication,
   and user-visible behavior.

Repository and local rendered truth can be validated here. Controller and
runtime claims require fresh operator evidence and must not be inferred from a
green historical incident record.

## Current Repository Baseline

### Reconciliation Graph

- `on-prem-platform-core`
- `on-prem-keycloak-secrets`
- `on-prem-bigbang-source`
- `on-prem-bigbang-foundation`
- `on-prem-bigbang-policy`
- `on-prem-bigbang-observability`
- `on-prem-platform-runtime`
- `on-prem-platform-services`

### Platform Capabilities Represented in Git

- Flux as platform and infrastructure reconciliation authority
- Big Bang family releases as the temporary package lifecycle intermediary
- ArgoCD as tenant workload delivery authority
- Vault and External Secrets Operator for secret storage and synchronization
- Kyverno and Kyverno Policies for admission and governance enforcement
- Istio and Cloudflare for in-cluster and edge exposure
- Prometheus, Grafana, Tempo, Loki, and Alloy for observability
- Keycloak for identity
- Airflow as a shared platform service

### Tenant Application Surfaces

- `listings-ingest`
- `mia`
- `oracle`
- `panchito`
- `rigoberta`

Presence in Git does not prove current runtime health. Runtime verification is
tracked separately where required.

## Closed Gaps

### Post-Incident Control-Plane Follow-Through

The grouped follow-through in `#259` is complete:

- `#255`: residual child HelmRelease debt was audited and follow-up cleanup was
  completed
- `#256`: `platform-runtime` composition and health-gate posture were reviewed
- `#257`: namespace and resource ownership contracts were normalized and made
  locally auditable
- `#258`: direct Flux package ownership was accepted as the long-term Big Bang
  boundary strategy

These items should not remain listed as open stability gaps.

### Namespace Ownership Ambiguity

Closed by:

- direct dependencies on namespace authorities
- `docs/namespace-resource-ownership-contracts.md`
- `scripts/audit-namespace-ownership.sh`

Future namespace-surface changes must update the ownership matrix and audit in
the same pull request.

### Big Bang Boundary Decision

Closed as an architecture question by
`docs/bigbang-boundary-strategy-2026-06.md`.

The decision is:

- current family releases remain temporary stabilization boundaries
- package lifecycle ownership moves directly into Flux in controlled waves
- Kiali is the extraction pilot
- the Istio family migrates last
- migration and package upgrades remain separate changes

The implementation is open, but the architectural choice is not.

## Active Stability Gaps

### 1. Package Ownership and Render-Parity Inventory

**Tracking:** `#300`

**Gap:** The repository does not yet contain the complete package-level input
needed to reproduce Big Bang-generated child releases directly.

Required evidence:

- enabled package versions and chart sources
- effective generated values
- umbrella-generated namespaces, secrets, policies, routes, and image pull
  secrets
- CRD and controller ordering
- explicit owner for every shared support resource
- render-parity method for package extraction

**Exit condition:** Kiali can be scoped as a direct-ownership pilot without
guessing at generated inputs or creating overlapping owners.

### 2. Stateful Continuity and Vault Lifecycle Safety

**Tracking:** `#275`, `#54`, `#45`, and related Vault hardening issues

**Gap:** The platform has recovered from Vault state loss, but prevention,
destructive lifecycle boundaries, and backup/restore evidence are incomplete.

Required outcomes:

- root cause and recurrence controls for local-path state loss
- explicit accepted and destructive Vault lifecycle operations
- tested backup and restore procedure before cluster or VM rebuilds
- durable ownership for Vault policy and authentication configuration

**Exit condition:** Rebuild, uninstall, namespace deletion, and storage recovery
paths are explicit enough that an operator does not improvise around stateful
data.

### 3. Policy Exception and Admission-Control Legibility

**Tracking:** `#231`, `#34`, and residual concerns from `#125`

**Gap:** Control-plane workloads still require legitimate service-account token
and policy exceptions, but those exceptions are not yet fully codified as a
reviewable platform contract.

Required outcomes:

- narrow, named automount exceptions
- CI validation against enforced Kyverno policy
- no stale admission or hook behavior hidden beneath green top-level status

**Exit condition:** A policy failure identifies the owning exception or
manifest directly rather than requiring live-cluster archaeology.

### 4. Runtime Reconciliation Boundaries

**Tracking:** `#53`

**Gap:** `platform/runtime` still aggregates Alloy glue, Vault resources,
Kyverno policies, and ArgoCD resources under one Flux Kustomization.

The removal of unnecessary health gates reduced blocking behavior, but it did
not make these controller-specific ownership surfaces independent.

**Exit condition:** The runtime graph either has controller-specific units or a
documented reason to retain the aggregate boundary after direct package
ownership begins.

### 5. Deployed Tool and Application Inventory

**Tracking:** `#304` for platform controller and service runtime evidence;
`#305` for tenant workload readiness

**Gap:** The repository lists intended tools and tenants, but does not yet
provide one current inventory that maps each surface to:

- owning reconciliation path
- namespace
- stateful dependencies
- ingress and identity dependencies
- secret dependencies
- current verification status
- platform, shared-service, or tenant ownership

**Exit condition:** Operators and app owners can identify the owner and critical
dependencies of every deployed surface without reconstructing the graph from
manifests.

### 6. Application Development Readiness

**Tracking:** `#305`, with workload failures routed to `#135`, `#136`, `#190`,
or other app-specific issues as appropriate

**Gap:** Repository onboarding and runtime readiness are not consistently
distinguished. Some applications have GitOps representation but still require
runtime verification or platform capability completion.

Required classification for each application:

- feature-ready
- runtime verification required
- platform cleanup required
- ownership clarification required
- separate product or platform-service decision required

**Exit condition:** App development priorities are based on verified platform
dependencies rather than repository presence alone.

### 7. Environment Semantics and Recovery Portability

**Tracking:** `#83` and environment documentation

**Gap:** On-prem is the active environment, but the sandbox boundary and
rebuild path are not yet implemented as a true disposable environment model.

**Exit condition:** Operators can state which environment is durable, which is
disposable, and how the same declared GitOps interfaces move between approved
environments without operator-specific redesign.

## Work That Is Not a Current Stability Gap

The following may be valid roadmap work, but should not displace the active
stability gaps unless priority changes explicitly:

- new persistence capabilities such as MinIO
- automated image update expansion
- new tenant-facing Airflow authentication features
- RabbitMQ capability development
- additional AI platform capabilities
- broad package upgrades during Big Bang extraction

This distinction prevents feature demand from being mislabeled as control-plane
repair.

## Current Priority Order

1. Complete package inventory and render-parity evidence in `#300`.
2. Close Vault recurrence and lifecycle-safety gaps.
3. Codify policy exceptions and admission validation.
4. Produce the deployed tool and application dependency inventory.
5. Classify application development readiness.
6. Revisit runtime decomposition as package ownership becomes direct.
7. Begin the Kiali extraction pilot only after inventory and rollback evidence
   are accepted.

## Authoritative Working Set

### Current Decisions and Contracts

- `docs/bigbang-boundary-strategy-2026-06.md`
- `docs/namespace-resource-ownership-contracts.md`
- `docs/bigbang-exit-plan.md`
- `docs/environment-semantics-plan.md`
- `docs/wait-true-justification-2026-06.md`

### Incident and Recovery Evidence

- `docs/gitops240-incident-summary-2026-06.md`
- `docs/residual-child-helmrelease-debt-audit-2026-06.md`
- `docs/vault-hardening-plan.md`
- `docs/vault-migration-plan.md`
- `docs/keycloak-recovery-notes.md`
- `docs/argocd-troubleshooting-notes-2026-03-30.md`
- `docs/alloy-receiver-troubleshooting-notes-2026-05.md`

### Graph and Application Context

- `docs/top-level-reconciliation-inventory-2026-05.md`
- `docs/fluxcd-reconciliation-order.md`
- `docs/tenant-app-deployment-plan.md`
- `docs/edge-exposure-plan.md`
- `docs/canary-rollout-pattern.md`

Historical proposals remain useful evidence, but they do not override accepted
decisions in the current working set.

## Stability Pause Rules

During the pause:

1. Honor Command Center priority and repo-native execution ownership.
2. Do not add platform surface unless required by an active, prioritized issue.
3. Treat direct package extraction under the accepted strategy as stabilization,
   not feature expansion.
4. Preserve package versions during ownership migration.
5. Require explicit rollback and non-overlapping ownership for every package
   handoff.
6. Route discoveries into bounded repo issues rather than informal notes.
7. Label every controller or runtime verification step as requiring cluster
   access.

## Exit Criteria for the Stability Pause

The pause can end when:

- package ownership inventory and render-parity method are accepted
- the first direct package pilot is proven without overlapping ownership
- Vault lifecycle and recovery boundaries are explicit and tested
- admission-control exceptions and CI validation are legible
- deployed tools and applications have a current dependency inventory
- application readiness is classified
- remaining platform hardening and app development work are cleanly separated
- fresh controller and runtime evidence confirms the intended baseline

## Review Triggers

Revisit this analysis when any of the following occurs:

- `#300` closes
- the first package moves out of the Big Bang umbrella
- a stateful continuity incident occurs
- runtime reconciliation boundaries change
- a new environment becomes active
- the stability pause exit criteria are claimed as complete

This document is the current gap analysis until one of those triggers produces
a newer dated revision.
