# Platform Stability Gap Analysis

**Date:** 2026-06-20

**Purpose:** Pause platform change churn long enough to establish a stable
baseline, identify the remaining gaps to a durable steady state, and prepare
for deeper exploration of what is deployed so the next phase can move from
platform repair into app and architecture development.

**Operating principle:** honor active Command Center items and repo issues, but
use this pause to stop guessing, inventory the platform honestly, and tighten
the operating model before adding more surface area.

## Execution Framework

This pause should run through the existing issue framework rather than around
it.

- Command Center items remain the higher-level execution queue.
- Repo issues remain the concrete unit of work and closure.
- The pause is not a suspension of accountability; it is a change in focus.
- New discoveries should be routed into the existing issue structure instead of
  being left as informal notes.

Within that framework, the work runs in two equal tracks:

- Platform tooling understanding
- App and architecture development

## Why This Pause Is Timely

The current incident tail has been reduced to manageable issue tracks:

- residual child-release debt is closed
- the Vault recovery incident is closed
- the remaining Vault work is now prevention and operating-model hardening

That is the right moment to stop broadening the platform and take stock of what
is actually deployed, what it does, and where the gaps still are.

This is not a freeze on all work. It is a controlled pause on new platform
motion so the team can:

- establish a known-good baseline
- map deployed tools and apps
- identify the unstable or under-documented edges
- decide what is ready for app and architecture development versus more
  platform hardening

## What “Stable” Means Here

For this repository, a stable state means:

- top-level reconciliation converges without surprise
- Vault, external-secrets, ArgoCD, and the Big Bang split are operating in the
  recovered baseline
- destructive lifecycle boundaries are documented
- active issue work is limited to the remaining prevention and semantics tracks
- app owners can rely on the platform surface without rediscovering platform
  mechanics every time they deploy

## Current Baseline Inventory

This inventory is derived from the current repo layout and the existing
environment split.

### Control Plane and Platform Foundations

- Flux entrypoint under `clusters/on-prem/`
- Big Bang umbrella and split surfaces under `bigbang/`
- foundational platform resources under `platform/core/`
- runtime control-plane resources under `platform/runtime/`
- platform services under `platform/services/`
- namespace and service-account baseline under `platform/namespaces/`

### Deployed Platform Tools

- Vault for shared secret storage
- External Secrets Operator for cluster secret sync
- ArgoCD for tenant application delivery
- Kyverno for policy enforcement
- Istio for mesh and ingress control
- Cloudflare tunnel and edge exposure controls
- Alloy for runtime telemetry and receiver hooks
- Airflow as a platform service workload
- Kiali as a mesh/observability-facing platform tool
- Big Bang as the umbrella release mechanism that still owns part of the stack

### Application Surfaces Already in the Repo

- `mia`
- `panchito`
- `rigoberta`
- `oracle`
- `listings-ingest`

### High-Value Secret and Identity Surfaces

- `platform/vault/`
- `platform/keycloak/`
- `platform/argocd/`
- `platform/policies/kyverno/`
- tenant `ExternalSecret` manifests across `tenants/`

## Existing Docs To Reuse

This pause should reuse the repo's existing docs as the authoritative working
set rather than duplicating them.

### Platform Inventory and Graph Shape

- `docs/top-level-reconciliation-inventory-2026-05.md`
- `docs/fluxcd-reconciliation-order.md`
- `docs/bigbang-exit-plan.md`
- `docs/bigbang-implementation-design-2026-06.md`
- `docs/bigbang-split-proposal-2026-06.md`

### Environment and Operating Model

- `docs/environment-semantics-plan.md`
- `docs/edge-exposure-plan.md`
- `docs/wait-true-justification-2026-06.md`

### Vault and Secret Management

- `docs/vault-hardening-plan.md`
- `docs/vault-migration-plan.md`
- `docs/tenant-onboarding-runbook.md`
- `docs/shared-redis-capability.md`

### Recovery and Incident History

- `docs/gitops240-incident-summary-2026-06.md`
- `docs/residual-child-helmrelease-debt-audit-2026-06.md`
- `docs/keycloak-recovery-notes.md`
- `docs/argocd-troubleshooting-notes-2026-03-30.md`
- `docs/alloy-receiver-troubleshooting-notes-2026-05.md`

### App and Workload Discovery

- `docs/tenant-app-deployment-plan.md`
- `docs/canary-rollout-pattern.md`
- `docs/mia-probe-hardening-plan.md`
- `docs/mia-ollama-heartbeat.md`
- `docs/rabbitmq-capability-evaluation.md`
- `docs/openclaw-whatsapp-persistence-pattern.md`

## Gap Analysis

### 1. Stable-State Definition Gap

What is missing:

- a concise “what is on-prem and what is sandbox” statement for operators
- a clear “what must never be treated as disposable” rule for Vault and other
  stateful services
- a single baseline inventory that says what is deployed and why
- an explicit statement that platform tooling and app/architecture work are
  equal tracks during the pause

Why it matters:

- without this, every incident turns into a fresh architecture debate

### 2. Platform Tooling Inventory Gap

What is missing:

- a current, human-readable inventory of deployed platform tools
- a clear mapping from tool to owning repo path and purpose
- a note on which tools are control-plane primitives versus product runtime
- a note on which tools are prerequisites for app development versus direct
  app dependencies

Why it matters:

- this is the bridge from platform repair to platform literacy
- you cannot build confidently on top of a platform if you cannot name the
  platform components or their ownership boundaries

### 3. App and Architecture Discovery Gap

What is missing:

- a current inventory of deployed apps and their deployment mode
- a mapping from app to namespace, ingress, and secret dependencies
- a list of which apps are platform-owned, tenant-owned, or shared
- a note on which application boundaries are still fuzzy or overloaded

Why it matters:

- this is the other half of the work, not a later phase
- app and architecture development should be driven by the deployed shape, not
  by assumptions

### 4. Operational Guardrail Gap

What is missing:

- a short rule set for destructive actions on Vault and other stateful services
- a default stance on namespace deletion, uninstall/reinstall, and PVC
  recreation
- a standard recovery checklist for stateful platform tools

Why it matters:

- the platform has already shown that “recreate it” is not a safe instinct for
  every component

### 5. App Development Readiness Gap

What is missing:

- a list of the apps that are ready for feature development
- a list of the apps that still need platform hardening before feature work
- a decision on whether each app should be treated as first-class product work
  or as infrastructure-adjacent platform work
- a decision on which architecture questions are still open and need design
  work rather than feature work

Why it matters:

- once the platform is stable, development effort should shift to the apps and
  architecture deployed on top of it, not to endlessly reshaping the control
  plane

## Pause Plan

During the pause:

1. Keep honoring active Command Center items and open repo issues.
2. Avoid widening platform surface area unless it is required by an active issue.
3. Build a living inventory of deployed tools and apps.
4. Identify the minimum stable baseline required for app and architecture work.
5. Separate platform hardening work from app and architecture development work.
6. Route new discoveries back into the existing issue framework.

## Discovery Plan

### Phase 1: Platform Inventory

Answer these questions from the repo and live cluster:

- What tools are deployed today?
- Which paths own them?
- Which ones are control-plane primitives versus operational tooling?
- Which ones are stateful and therefore continuity-sensitive?

### Phase 2: Application and Architecture Inventory

Answer these questions next:

- What apps are actually deployed?
- Which namespace and ingress path does each app use?
- What secret dependencies does each app have?
- Which apps are tenant-facing versus platform-facing?
- Which app boundaries still need architectural clarification?

### Phase 3: Development Surface Definition

For each deployed app, classify:

- feature-ready
- needs platform cleanup first
- needs ownership clarification
- should be treated as a separate product line

## Exit Criteria for the Pause

The pause can end when:

- the deployed platform tool inventory is explicit
- the deployed app inventory is explicit
- the stability gaps are ranked by risk
- the open issues are cleanly partitioned between platform hardening and app
  and architecture development
- the team can resume with a clear bias toward deliberate app and architecture
  work instead of more control-plane churn

## Recommended Next Docs

- `docs/top-level-reconciliation-inventory-2026-05.md`
- `docs/fluxcd-reconciliation-order.md`
- `docs/bigbang-exit-plan.md`
- `docs/environment-semantics-plan.md`
- `docs/vault-hardening-plan.md`
- `docs/vault-migration-plan.md`
