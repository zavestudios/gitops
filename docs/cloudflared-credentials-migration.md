# Cloudflare Tunnel Credentials-File Migration

## Purpose

Migrate cloudflared from token-based (remote config) to credentials-file based (local GitOps config) to achieve full infrastructure-as-code control over tunnel configuration.

## Problem

**Token-based mode (`--token`):**
- Pulls ingress configuration from Cloudflare Zero Trust dashboard
- Local ConfigMap changes are ignored
- Config is split between dashboard (remote) and GitOps (local)
- Not auditable or version-controlled

**Credentials-file mode (`--credentials-file`):**
- Uses local ConfigMap for all ingress rules
- Full GitOps control
- All configuration version-controlled and auditable
- Required for DoD compliance and infrastructure-as-code best practices

## Changes Made

### 1. Deployment (`platform/cloudflare/deployment.yaml`)

**Removed:**
```yaml
args:
  - --token
  - $(TUNNEL_TOKEN)
env:
  - name: TUNNEL_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflared-token
        key: token
```

**Added:**
```yaml
args:
  - --credentials-file
  - /etc/cloudflared/creds/credentials.json
volumeMounts:
  - name: creds
    mountPath: /etc/cloudflared/creds
    readOnly: true
volumes:
  - name: creds
    secret:
      secretName: cloudflared-credentials
      items:
      - key: credentials.json
        path: credentials.json
```

### 2. ExternalSecret

**Renamed:** `cloudflared-token.external-secret.yaml` → `cloudflared-credentials.external-secret.yaml`

**Changed:**
```yaml
# Old
target:
  name: cloudflared-token
data:
  - secretKey: token
    remoteRef:
      property: token

# New
target:
  name: cloudflared-credentials
data:
  - secretKey: credentials.json
    remoteRef:
      property: credentials
```

### 3. ConfigMap (`platform/cloudflare/configmap.yaml`)

**Already updated with:**
```yaml
originRequest:
  httpHeaders:
    X-Forwarded-Proto:
      - https
```

This will now take effect since credentials-file mode uses local ingress config.

## Manual Migration Steps

### Step 1: Get Tunnel Credentials from Cloudflare

**Requires Cloudflare dashboard access:**

1. Log into Cloudflare Zero Trust dashboard
2. Navigate to **Networks** → **Tunnels**
3. Find your tunnel (ID should match what's in the current deployment)
4. Click the three dots → **View** or **Configure**
5. Look for tunnel credentials or download the credentials JSON file

The credentials JSON looks like:
```json
{
  "AccountTag": "your-account-id",
  "TunnelSecret": "base64-encoded-secret",
  "TunnelID": "your-tunnel-id"
}
```

**Alternative method (if you have cloudflared CLI locally):**

If the tunnel was created locally, the credentials file might be at:
```bash
~/.cloudflared/<tunnel-id>.json
```

### Step 2: Store Credentials in Vault

**Requires Vault access:**

```bash
# Store the credentials JSON in Vault
vault kv put platform/cloudflare \
  credentials=@/path/to/tunnel-credentials.json
```

Or if using Vault UI:
1. Navigate to `kv/platform/cloudflare`
2. Add key: `credentials`
3. Paste the entire JSON content as the value

### Step 3: Remove Old Token from Vault (Optional Cleanup)

After verifying the new setup works:

```bash
# Update the secret to remove the old token key
vault kv patch platform/cloudflare -delete=token
```

### Step 4: Remove Dashboard Ingress Rules

**Requires Cloudflare dashboard access:**

After migration succeeds and you've verified local config is working:

1. Go to Networks → Tunnels → Your tunnel
2. Remove all ingress rules from the dashboard
3. Leave only the catch-all rule: `http_status:404`

This ensures all ingress config comes from GitOps, not the dashboard.

## Deployment Sequence

1. **Store credentials in Vault** (Step 2 above)
2. **Merge this PR** to gitops main branch
3. **FluxCD will reconcile:**
   - New ExternalSecret pulls credentials from Vault
   - Deployment restarts with `--credentials-file` flag
   - ConfigMap with headers is now active
4. **Verify tunnel is running:**
   ```bash
   kubectl logs -n platform deployment/cloudflared
   ```
5. **Test X-Forwarded-Proto header:**
   ```bash
   kubectl exec -n panchito deployment/panchito -- \
     curl -s http://localhost:8000/api/v1/health -H "X-Forwarded-Proto: https"
   ```
6. **Test panchito Keycloak flow** in browser

## Validation

### Success Criteria

1. **cloudflared pods running** without errors
2. **Ingress config uses local ConfigMap:**
   ```bash
   kubectl logs -n platform deployment/cloudflared | grep "Updated to new configuration"
   ```
   Should show `X-Forwarded-Proto` in the config output
3. **Panchito redirects with https:// redirect_uri:**
   Navigate to `https://panchito-on-prem.zavestudios.com/`
   Should redirect to Keycloak with:
   ```
   redirect_uri=https://panchito-on-prem.zavestudios.com/auth/callback
   ```
   (Not `http://`)

### Rollback Plan

If migration fails:

1. **Revert the gitops PR merge**
2. **Verify old token is still in Vault** at `platform/cloudflare:token`
3. **FluxCD will reconcile back to token-based mode**

## DoD Compliance Benefits

This migration achieves:

- **Infrastructure as Code**: All tunnel config in version control
- **Audit Trail**: Git history shows all config changes
- **Defense in Depth**: Header validation through proxy chain
- **Reduced Attack Surface**: No dashboard-managed config to compromise
- **Compliance**: Meets requirements for auditable infrastructure

## Related

- Closes gitops#138 (enables Keycloak authentication)
- Implements proper X-Forwarded-Proto header forwarding
- Required for panchito#24 ProxyFix middleware to function

## References

- Cloudflare Tunnel credentials documentation: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/local-management/
- Cloudflare Tunnel ingress configuration: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/local-management/ingress/
