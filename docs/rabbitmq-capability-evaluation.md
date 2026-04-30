# RabbitMQ Capability Evaluation

**Status:** OpenShift Local findings captured
**Updated:** 2026-04-29
**Related Issue:** `#139`

## Summary

RabbitMQ has now been exercised in the `openshift-local` proving surface.

Current recommendation remains: **defer promotion into governed GitOps**.

The OpenShift exercise answered the core fluency question for this issue:

- RabbitMQ can run successfully on OpenShift Local with persistence and basic
  messaging validation
- the operator lifecycle is legible enough to support
- the main OpenShift-specific friction is Security Context Constraint handling,
  not the RabbitMQ resource model itself
- the current platform still lacks a governed tenant need strong enough to
  justify adding this operational burden

This keeps the platform aligned with the Formation operating model:

- prove candidate capabilities in a POC repository first
- promote only when reusable platform value is concrete
- keep GitOps as lifecycle authority if the capability graduates

## Repository Scope

Per `REPO_TAXONOMY.md`, this work is **cross-repo by nature**:

- `openshift-local` is the POC proving surface and remains outside governed
  GitOps
- `gitops` is the eventual infrastructure authority if RabbitMQ is promoted

The resulting workflow is:

1. prove deployment and operating behavior in `openshift-local`
2. record the promotion decision and target GitOps shape here
3. only then add governed manifests under `gitops/platform/`

No governed RabbitMQ manifests should be added to this repository yet.

## What The OpenShift Exercise Proved

The `openshift-local` artifact now demonstrates:

- RabbitMQ Cluster Operator installation from upstream release manifests
- successful `RabbitmqCluster` reconciliation in a dedicated project
- operator-generated credentials and working AMQP connectivity
- PVC-backed persistence with expected restart behavior
- internal service discovery and management endpoint exposure

The most important OpenShift-specific findings were:

- the deployment required `privileged` SCC for the RabbitMQ workload service
  account
- `anyuid` alone was insufficient because deprecated seccomp annotations still
  triggered SCC rejection
- OpenShift Local storage behavior rounded the requested `10Gi` volume up to a
  `30Gi` allocation under the default storage class
- the operator was installed manually from upstream manifests rather than
  through OperatorHub

These findings make the deployment understandable, but they also raise the
security and governance threshold for any future governed rollout.

## Platform Decision

RabbitMQ should **not** be promoted into governed platform state yet.

Promotion remains conditional on a governed workload needing broker semantics
that the current shared Redis pattern does not satisfy well enough, such as:

- durable queue semantics with acknowledgements
- dead-letter routing
- topic or fanout exchange patterns
- stronger asynchronous workflow semantics than cache-style infrastructure

If the need is only caching or lightweight background jobs, the current Redis
pattern remains the lower-burden choice.

## Preferred GitOps Shape If Promoted

If a future workload justifies promotion, RabbitMQ should be modeled as a
**platform-owned shared service** under the Flux-managed platform surface, not
as a tenant-managed ArgoCD application.

Target shape:

- operator installation under `gitops/platform/`
- `RabbitmqCluster` custom resource under `gitops/platform/`
- platform-owned secret and access workflow through Vault and `ExternalSecret`
- no tenant repository owning broker lifecycle directly

This follows `CONTROL_PLANE_MODEL.md`:

- CI may propose changes
- GitOps remains state authority
- runtime is only a reflection of declared Git state

## Tenancy Model To Reuse Later

The preferred first governed shape remains intentionally narrow:

- one shared RabbitMQ cluster
- one vhost per tenant workload
- one tenant user per workload
- internal-only service exposure
- operator or admin credentials retained for platform operators only

This is the minimum bounded model that looks materially stronger than the
current shared Redis capability.

## Governance And Runbook Gaps Before Promotion

The POC surfaced concrete prerequisites for any future governed rollout:

- document and approve why `privileged` SCC is acceptable for this workload
- define a durable process for SCC review and renewal
- document tenant credential issuance and rotation end to end
- document backup, restore, PVC failure, and unhealthy node recovery behavior
- confirm the operator no longer depends on deprecated seccomp behavior, or
  accept that dependency explicitly

Until those exist, keeping RabbitMQ out of governed GitOps is the correct
platform decision.

## POC References

Primary proving artifacts:

- `openshift-local/docs/patterns/rabbitmq-platform-evaluation.md`
- `openshift-local/manifests/rabbitmq/`
- `openshift-local/scripts/test_rabbitmq.py`
- `openshift-local/scripts/test_persistence.py`

## Manual Validation

Run these from the `openshift-local` repository.

**Requires cluster access:**

```bash
oc get crd rabbitmqclusters.rabbitmq.com
oc apply -f manifests/rabbitmq/project.yaml
oc apply -f manifests/rabbitmq/rabbitmq-cluster.yaml
oc get rabbitmqcluster -n rabbitmq-platform
oc get pods -n rabbitmq-platform
oc get pvc -n rabbitmq-platform
oc get secret -n rabbitmq-platform platform-rabbitmq-default-user
```
