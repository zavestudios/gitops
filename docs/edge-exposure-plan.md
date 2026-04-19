# Edge Exposure Plan

Status: **COMPLETE** - Edge hardening implemented

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

## Implementation Status

Edge hardening completed April 2026:

- ✓ Explicit DNS records created for all `-on-prem` hostnames only
- ✓ Cloudflare Access policies protecting all operator/admin UIs
- ✓ Wildcard DNS exposure retired
- ✓ Legacy hostname DNS records removed
- ✓ Infrastructure managed as code in Terraform
- ✓ Defense-in-depth: edge authentication + application authentication

All operator UIs now require Cloudflare Access authentication before reaching the application layer.

## Current Repo Evidence

### Tunnel Behavior

`platform/cloudflare/configmap.yaml` routes all tunnel traffic to:

- `http://public-ingressgateway.istio-gateway.svc.cluster.local:80`

There is no host-based filtering in the cloudflared config today.

### Istio Public Gateway Behavior

`bigbang/values.yaml` configures the public gateway to accept:

- `*.zavestudios.com`

This aligns with the current wildcard Cloudflare posture, but it is broader than necessary for the intended surface area.

## Current Exposure Matrix

Current hostname exposure model:

| Hostname Pattern | Role | Edge Protection | Notes |
| --- | --- | --- | --- |
| `*-on-prem.zavestudios.com` (operator UIs) | Platform admin surfaces | Cloudflare Access | ArgoCD, Vault, Grafana, Prometheus, Alertmanager, Kiali, Loki, Policy Reporter |
| `sso-on-prem.zavestudios.com` | Keycloak IdP | Public | Identity provider must be publicly accessible for OIDC flows |
| `panchito-on-prem.zavestudios.com` | Tenant application | Public | Authenticated via Keycloak OIDC at application layer |

## Security Architecture

### Defense-in-Depth Model

**Operator/Admin UIs:**
1. Edge layer: Cloudflare Access (authorized operator emails only)
2. Application layer: Service authentication (local admin, pending Keycloak SSO per `gitops#90`)

**Public Applications:**
1. No edge restriction (intentionally public)
2. Application layer: Keycloak OIDC authentication

**Identity Provider (Keycloak):**
1. Intentionally public (no Cloudflare Access)
2. Required for OIDC flows; edge protection would break authentication chains

### DNS Model

- No wildcard DNS records (`*.zavestudios.com`)
- Explicit DNS records for intentional exposure only
- All operator UIs use `-on-prem` suffix for clarity
- All DNS and Access configuration managed in Terraform

### Adding New Services

When exposing a new service:

1. Create explicit DNS record (no wildcards)
2. Determine exposure model:
   - Operator UI → Add Cloudflare Access policy
   - Public app → No edge restriction, use application-layer auth
3. Document in this file
4. Manage via infrastructure-as-code

## Verification

To verify edge protection is working:

1. Open an incognito/private browser window
2. Navigate to any operator UI (e.g., `argocd-on-prem.zavestudios.com`)
3. Expected: Cloudflare Access authentication prompt before reaching application
4. Public services (panchito, sso) should be directly accessible without Access prompt

## Related Work

- `gitops#90`: Add Keycloak SSO to operator UIs (application-layer auth improvement)
- Infrastructure code: `kubernetes-platform-infrastructure/terraform-cloudflare/`

## Notes

- Edge protection (Cloudflare Access) and application authentication (Keycloak SSO) are complementary layers
- Both layers should remain in place for defense-in-depth
- All infrastructure changes should be made via Terraform, not manually in Cloudflare UI
