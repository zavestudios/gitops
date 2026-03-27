# Edge Exposure Plan

Status: initial hardening implemented

Related issues:

- `gitops#55` Rename the current environment and introduce a true local sandbox

## Summary

The current edge posture is broader than intended.

Today, the effective shape is:

- Cloudflare DNS includes wildcard routing for `*.zavestudios.com`
- the cloudflared tunnel forwards all incoming traffic to the Istio public ingress gateway
- the Istio public gateway accepts `*.zavestudios.com`
- there is no repo evidence of Cloudflare Access or equivalent edge gating for operator UIs

That means traffic for arbitrary single-level subdomains can reach the cluster edge, even if the eventual application response is only a `404`.

The platform should move to:

- explicit DNS records only for intentionally exposed hosts
- an explicit allowlist of publicly reachable hostnames
- Cloudflare Access protection for operator/admin UIs
- no reliance on wildcard edge exposure as the default posture

## Current Status Note

Initial edge hardening has now been completed for the current environment:

- explicit DNS records were created for the retained operator/admin hosts
- Cloudflare Access was added for the retained operator/admin hosts
- wildcard tunnel DNS exposure via `*.zavestudios.com` and `*.sandbox.zavestudios.com` was retired
- `mia-on-prem.zavestudios.com` and `mia-canary-on-prem.zavestudios.com` were intentionally retired after removal of the orphaned public ingress path

The remaining work on this topic is follow-on tightening and codification, not emergency exposure reduction.

## Current Repo Evidence

### Tunnel Behavior

[platform/cloudflare/configmap.yaml](/Users/xavierlopez/Dev/gitops/platform/cloudflare/configmap.yaml) routes all tunnel traffic to:

- `http://public-ingressgateway.istio-gateway.svc.cluster.local:80`

There is no host-based filtering in the cloudflared config today.

### Istio Public Gateway Behavior

[bigbang/values.yaml](/Users/xavierlopez/Dev/gitops/bigbang/values.yaml) configures the public gateway to accept:

- `*.zavestudios.com`

This aligns with the current wildcard Cloudflare posture, but it is broader than necessary for the intended surface area.

## Current Exposure Matrix

Based on current cluster observations and repo state, the relevant hosts are:

| Hostname | Current Role | Proposed Exposure | Notes |
| --- | --- | --- | --- |
| `argocd.zavestudios.com` | Operator UI | Cloudflare Access | Admin surface; should not be openly reachable without edge auth. |
| `vault.zavestudios.com` | Operator/admin UI | Cloudflare Access | Sensitive admin surface. |
| `grafana-on-prem.zavestudios.com` | Operator UI | Cloudflare Access | Useful UI, but not a public app. |
| `sso.zavestudios.com` | Keycloak IdP | Public by design | Identity plane endpoint; do not place Cloudflare Access in front of Keycloak itself. |
| `policyreporter.zavestudios.com` | Operator UI | Cloudflare Access | Reporting UI, not a public app. |
| `prometheus.zavestudios.com` | Operator UI | Cloudflare Access | Observability admin surface. |
| `alertmanager.zavestudios.com` | Operator UI | Cloudflare Access | Observability admin surface. |
| `loki.zavestudios.com` | Operator/API surface | Cloudflare Access or retire | Keep only if there is a real operator need. |
| `mia-on-prem.zavestudios.com` | Removed public path | Retire | `mia` is now intentionally internal/operator-tunneled. |
| `mia-canary-on-prem.zavestudios.com` | Removed public path | Retire | Canary ingress was removed; do not keep DNS just because the hostname exists historically. |

## Recommended Target State

### 1. Explicit DNS Allowlist

Replace broad wildcard DNS exposure with explicit records for only the hosts you intend to expose.

Default principle:

- no wildcard `*.zavestudios.com` record pointed at the cluster tunnel
- no wildcard `*.sandbox.zavestudios.com` record pointed at the cluster tunnel

Preferred record set is explicit and minimal.

### 2. Access-Protect Operator UIs

Apply Cloudflare Access to operator/admin surfaces:

- `argocd.zavestudios.com`
- `vault.zavestudios.com`
- `grafana-on-prem.zavestudios.com`
- `policyreporter.zavestudios.com`
- `prometheus.zavestudios.com`
- `alertmanager.zavestudios.com`
- `loki.zavestudios.com` if retained

Do **not** put Cloudflare Access in front of `sso.zavestudios.com`. Keycloak is
the platform identity provider, so layering Cloudflare Access in front of it would
create a second identity gate and complicate OIDC login flows for downstream apps.

### 3. Retire Unneeded App Hosts

Retire public hosts that no longer have an intended exposure path:

- `mia-on-prem.zavestudios.com`
- `mia-canary-on-prem.zavestudios.com`

### 4. Keep Public App Exposure Explicit

If a future tenant application must be public:

- create an explicit DNS record
- create the platform routing intentionally
- document whether it is public-by-design or Access-protected

Do not rely on a wildcard DNS/tunnel posture to make that decision implicitly.

## Suggested Rollout Order

1. Build the explicit hostname allowlist.
2. Add or confirm Cloudflare Access policies for operator/admin hosts.
3. Remove DNS records for hosts that should no longer exist.
4. Remove wildcard DNS records once explicit records and Access policies are confirmed.
5. Optionally tighten the cloudflared/ingress posture further if wildcard host acceptance is no longer needed.

## Manual Verification Checklist

**Requires cluster access:**

Before wildcard retirement:

```bash
dig +short argocd.zavestudios.com
dig +short vault.zavestudios.com
dig +short grafana-on-prem.zavestudios.com
dig +short prometheus.zavestudios.com
dig +short alertmanager.zavestudios.com
dig +short loki.zavestudios.com
```

After Cloudflare Access rollout:

- verify operator UIs require Access before application login
- verify intended admins can still reach them

After DNS cleanup:

- confirm retired hosts no longer resolve or no longer route to the cluster edge
- confirm remaining allowlisted hosts still resolve and serve as intended

## Notes

- This plan is intentionally about edge exposure, not workload authentication design.
- Application login pages are not a substitute for edge access control on operator/admin surfaces.
- The current broad exposure posture was acceptable during early formation, but it should not remain the steady-state model.
