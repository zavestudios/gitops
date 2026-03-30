# ArgoCD Troubleshooting Notes

**Status:** Active  
**Started:** 2026-03-30  
**Scope:** Scratch incident log for ArgoCD pod and application-group troubleshooting  
**Owning repo:** `gitops`  
**Related repo(s):** `kubernetes-platform-infrastructure` if the issue traces to cluster substrate or Big Bang platform install

## Resolved Outcome

- ArgoCD was not in active outage during this session
- tenant Applications remained `Synced` and `Healthy`
- two durable GitOps fixes were identified and merged:
  - `argocd/private-registry` is now created declaratively from Vault path `platform/ghcr`
  - Big Bang ArgoCD package now forces `automountServiceAccountToken: false` via package-level post-renderers
- one stale runtime artifact was removed manually:
  - deleted leftover `redis-clean-upgrade` hook job in namespace `argocd`
- after reconciliation:
  - `FailedToRetrieveImagePullSecret` warnings for `private-registry` stopped
  - Kyverno `automountServiceAccountToken` warning noise for ArgoCD workloads stopped

This note remains incident history, not a formal runbook.

## Purpose

Capture this troubleshooting session in a lightweight format that can be promoted into a runbook later if the investigation becomes expensive, crosses multiple control planes, or reveals a repeatable failure class.

This note is intentionally not a polished runbook. It is working memory for:
- observed symptoms
- control-plane boundary being inspected
- checks performed
- conclusions
- follow-up actions

## Repo Scope

Per `platform-docs/_platform/REPO_TAXONOMY.md` and `GITOPS_MODEL.md`:

- `gitops` is the primary repo for ArgoCD application registration and tenant desired state
- `kubernetes-platform-infrastructure` is only in scope if the failure involves cluster substrate, node health, storage, networking, or the platform install path outside normal tenant GitOps state

Current assessment:
- change scope is currently **single-repo** (`gitops`) until evidence points to a substrate or platform-install problem

## Initial Symptom

- One pod in the ArgoCD app group reportedly showed issues over the last few days
- Exact pod name, namespace status, restart pattern, and failure mode still need confirmation

## Boundary Ladder

Use this sequence during investigation:

1. Declared truth
   - `gitops` desired state for ArgoCD and related applications
2. Rendered truth
   - Big Bang or Helm-rendered values and manifests
3. Controller truth
   - Flux reconciliation for platform state
   - ArgoCD application/controller state where relevant
4. Live runtime truth
   - pod status, events, logs, node placement, resource pressure
5. User-visible behavior
   - sync failures, degraded app status, UI/API symptoms

## Working Hypotheses

- transient pod restart due to resource pressure or node disruption
- controller reconciliation drift between Flux-managed platform state and live runtime
- ArgoCD component issue introduced by chart values, upstream image, or dependency behavior
- storage, DNS, ingress, or secret dependency causing a repeated readiness or startup failure

## Session Log

### 2026-03-30

#### Observations

- Session opened to investigate recent ArgoCD pod instability
- live cluster evidence captured from `kubectl -n argocd get events --sort-by=.lastTimestamp | tail -n 50`
- events show repeated `PolicyViolation` warnings around 28-30 minutes before capture for multiple ArgoCD resources:
  - `argocd-application-controller`
  - `argocd-server`
  - `argocd-repo-server`
  - `argocd-applicationset-controller`
  - `argocd-notifications-controller`
  - `argocd-dex-server`
- policy name:
  - `disallow-auto-mount-service-account-token/automount-pods`
- validation message indicates `spec.automountServiceAccountToken` is explicitly enabled where policy expects unset or `false`
- more recent events show repeated `FailedToRetrieveImagePullSecret` warnings for ArgoCD pods and `redis-bb` pods:
  - missing or unreadable image pull secret `private-registry`
- recent event also shows:
  - `job/redis-clean-upgrade`
  - `FailedCreate`
  - service account `argocd/redis-upgrade-sa` not found
- follow-up runtime checks show:
  - all ArgoCD core pods are currently `Running`
  - all tenant ArgoCD Applications are currently `Synced` and `Healthy`
  - `redis-bb-master-0` is `Running` and `Ready`
  - `redis-clean-upgrade` still exists as a failed Helm hook job
  - `private-registry` secret does not exist in namespace `argocd`
  - no `ExternalSecret` objects exist in namespace `argocd`
- Big Bang HelmRelease status as of 2026-03-30:
  - namespace `bigbang`
  - release `bigbang.v21`
  - chart `bigbang@3.17.0`
  - `Ready=True`
  - last deployed at `2026-03-30T17:40:19Z`

#### Checks Performed

- identified `gitops` as primary owning repository
- confirmed ArgoCD references exist in:
  - `gitops/bigbang/values.yaml`
  - `gitops/platform/argocd/applications/`
- confirmed potential secondary ownership in `kubernetes-platform-infrastructure` only if the problem is substrate-related
- reviewed recent `gitops` history for ArgoCD-related changes within the last 14 days
- identified a recent known failure class on 2026-03-28:
  - commit `e94ccfa`
  - disabled `argocd.values.redis-bb.cleanUpgrade`
  - commit message states the job was causing `ImagePullBackOff` because it used a hardcoded Iron Bank `kubectl` image
- confirmed ArgoCD package overrides in `bigbang/values.yaml` currently include:
  - `upgradeJob.enabled: false`
  - `redis-bb.cleanUpgrade.enabled: false`
  - public image overrides for ArgoCD core images and `dex`
- confirmed `redis-clean-upgrade` job manifest still present in-cluster includes:
  - `helm.sh/hook: pre-upgrade`
  - image `registry1.dso.mil/ironbank/big-bang/base:2.1.0`
  - service account `redis-upgrade-sa`
  - `imagePullSecrets: private-registry`
- confirmed Git currently contains a platform GHCR ExternalSecret only for namespace `kyverno`, not `argocd`

#### Conclusions So Far

- start in `gitops`
- do not assume cross-repo impact until runtime evidence points outside GitOps state ownership
- likely recent symptom candidate is not necessarily `argocd-server` or `argocd-application-controller`
- more likely recent churn involved a Big Bang-managed ArgoCD hook or subcomponent job, especially `redis-bb`
- next live checks should explicitly distinguish:
  - core ArgoCD control-plane pods
  - ArgoCD Redis pods
  - one-shot Jobs or hook pods
  - tenant Applications showing degraded health through ArgoCD UI/API
- active runtime evidence suggests three parallel conditions:
  - Kyverno policy friction against ArgoCD pod specs
  - missing `private-registry` image pull secret in `argocd`
  - unexpected `redis-clean-upgrade` job creation despite desired-state intent to disable `redis-bb.cleanUpgrade`
- the `redis-clean-upgrade` failure is especially important because it suggests one of:
  - wrong Helm values path for the installed chart version
  - stale Helm release values not reflecting current Git state
  - chart logic creating a different cleanup job than the one already disabled in Git
- still not enough evidence yet to say whether core ArgoCD availability is impaired or only noisy
- ArgoCD is currently healthy at the runtime and user-visible layers
- the originally observed issue is best interpreted as configuration and reconciliation noise, not a current control-plane outage
- the remaining issues are:
  - stale or repeatedly retried `redis-clean-upgrade` Helm hook behavior
  - missing `private-registry` secret reference in namespace `argocd`
  - Kyverno policy friction around `automountServiceAccountToken`
- because Big Bang successfully upgraded on 2026-03-30 while the old hook job remains, the failed job may be a leftover artifact from a prior revision rather than evidence of current release failure
- however, the missing `private-registry` secret is a real GitOps gap because the namespace references it with no Git-managed source in current repo state
- durable fix started in `gitops`:
  - added namespace-local `ExternalSecret` for `argocd/private-registry`
  - created `platform/argocd/kustomization.yaml`
  - updated `platform/runtime/kustomization.yaml` to reconcile `../argocd/` rather than only `../argocd/applications/`

#### Next Checks

- determine whether `redis-clean-upgrade` should be explicitly cleaned up after successful Big Bang upgrade
- determine whether `private-registry` should be provisioned in `argocd` or removed from package references if no private pulls are needed
- determine whether ArgoCD package values need explicit `automountServiceAccountToken: false` overrides to satisfy Kyverno without warning noise

## Manual Runtime Checks

These require cluster access and must be run by a human.

**Run manually by human**

```bash
kubectl -n argocd get pods
kubectl -n argocd get pods -o wide
kubectl -n argocd get jobs
kubectl -n argocd get all | grep -E 'argocd|redis|upgrade|cleanup|clean'
kubectl -n argocd describe pod <argocd-pod-name>
kubectl -n argocd logs <argocd-pod-name> --all-containers --tail=200
kubectl -n argocd get events --sort-by=.lastTimestamp | tail -n 50
```

**Run manually by human**

```bash
flux get kustomizations -A
flux get helmreleases -A
kubectl -n argocd get application
kubectl -n argocd get deploy,statefulset
```

## Promotion Trigger

Promote this note into a durable runbook if any of the following become true:

- the same ArgoCD failure pattern has happened more than once
- the investigation crosses three or more control planes
- recovery requires manual non-Git repair
- the root cause is not obvious from the first symptom
- the same check sequence is likely to be reused later

## Open Questions

- Which exact ArgoCD component was unhealthy?
- Did the issue self-recover or is it still active as of 2026-03-30?
- Was the first symptom in ArgoCD itself, in Flux-managed platform reconciliation, or only in a tenant application surfaced through ArgoCD?
