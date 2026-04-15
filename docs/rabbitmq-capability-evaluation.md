# RabbitMQ Capability Evaluation

**Status:** Draft
**Updated:** 2026-04-14
**Related Issue:** `#139`

## Summary

Evaluate RabbitMQ as a possible platform-managed messaging capability.

Current recommendation: **defer promotion into governed GitOps until the
OpenShift Local POC proves a clear tenant use case, acceptable operator burden,
and an end-to-end secrets model.**

This aligns with the platform operating model:

- start exploratory work in a POC repository
- only promote into governed repos when reusable platform value is clear
- keep GitOps as lifecycle authority if the capability graduates

## Repository Scope

Per `REPO_TAXONOMY.md`:

- `openshift-local` is the proving surface and remains outside governed GitOps
- `gitops` is the eventual infrastructure authority if RabbitMQ is promoted

This issue is therefore **cross-repo by nature**:

1. prove the operational model in `openshift-local`
2. document the promotion decision in `gitops`
3. only then add governed manifests to `gitops/platform/`

## Should RabbitMQ Be Platform-Managed?

Not yet.

RabbitMQ should be promoted only if a governed workload needs capabilities that
the current Redis pattern does not satisfy well enough, such as:

- durable queue semantics with acknowledgements
- dead-letter routing
- topic/fanout exchange patterns
- stricter broker semantics for asynchronous workflows

If the need is only caching or lightweight background jobs, the current shared
Redis capability remains the lower-burden choice.

## Preferred Reconciliation Model If Promoted

If promoted, RabbitMQ should be modeled as a **platform-owned shared service**
under the Flux-managed platform surface, not as a tenant-managed ArgoCD
application.

Target shape:

- operator installation under `gitops/platform/`
- `RabbitmqCluster` custom resource under `gitops/platform/`
- tenant workloads consume connection material through Vault and
  `ExternalSecret`
- no tenant owns the broker lifecycle directly

This follows `CONTROL_PLANE_MODEL.md`:

- CI may propose changes
- GitOps remains state authority
- runtime is only a reflection of declared Git state

## Candidate Tenancy Model

Preferred first production shape:

- one shared RabbitMQ cluster
- one vhost per tenant
- one tenant user per workload
- internal-only service exposure
- operator/admin credentials retained for platform operators only

This keeps the initial model bounded while remaining more structured than the
current shared Redis capability.

## Operational Burden To Prove

Before promotion, the POC must show that the following are manageable:

- operator installation and upgrade behavior
- PVC sizing and restart behavior
- backup and restore expectations
- queue/node health diagnostics
- tenant credential issuance and rotation
- resource overhead relative to the value delivered

If these remain opaque or expensive, the capability should stay deferred.

## Required Runbooks Before Promotion

Minimum runbooks expected before a governed rollout:

- install/upgrade the RabbitMQ operator
- validate `RabbitmqCluster` health and reconciliation
- provision tenant credentials and Vault mappings
- debug PVC/storage failures
- debug queue backlog and unhealthy node conditions
- document recovery boundaries and any break-glass actions

## POC Reference

The current proving artifact lives in:

- `openshift-local/docs/patterns/rabbitmq-platform-evaluation.md`
- `openshift-local/manifests/rabbitmq/`

## Manual Validation

**Requires cluster access:**

```bash
oc get crd rabbitmqclusters.rabbitmq.com
oc apply -f manifests/rabbitmq/project.yaml
oc apply -f manifests/rabbitmq/rabbitmq-cluster.yaml
oc get rabbitmqcluster -n rabbitmq-platform
oc get pods -n rabbitmq-platform
oc get pvc -n rabbitmq-platform
```
