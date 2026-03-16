# OpenClaw WhatsApp Persistence Pattern

This document defines the operational pattern for OpenClaw WhatsApp channel persistence in Kubernetes deployments.

Related: Issue #10 (WhatsApp credential persistence), Issue #12 (operations documentation)

## Purpose

- Ensure WhatsApp session credentials persist across pod restarts.
- Enable auto-reconnect without manual re-pairing.
- Provide recovery procedures for credential loss or startup failures.

## Architecture Pattern

OpenClaw uses the Signal protocol for WhatsApp integration. Session credentials must be persisted to survive pod lifecycle events.

**Required components:**

- PersistentVolumeClaim for OpenClaw data directory
- initContainer to seed default configuration on first boot
- volumeMount mapping OpenClaw config directory to PVC
- WhatsApp disabled in default image config (safe first boot)

**Persistence structure:**

```
/home/node/.openclaw/
├── credentials/
│   └── whatsapp/
│       └── <account-id>/       # Session files (~800+ files)
├── openclaw.json               # Runtime config
└── [other OpenClaw directories]
```

## Deployment Pattern

**PersistentVolumeClaim:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <workload>-data
  namespace: <namespace>
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: <storage-class>
  resources:
    requests:
      storage: 1Gi
```

**initContainer (config seed):**

```yaml
initContainers:
- name: seed-config
  image: <openclaw-image>
  command:
  - sh
  - -c
  - |
    if [ ! -f /data/openclaw.json ]; then
      cp -r /home/node/.openclaw/* /data/
      echo "Seeded initial config to persistent volume"
    else
      echo "Config already exists on persistent volume, skipping seed"
    fi
  volumeMounts:
  - name: data
    mountPath: /data
```

**Container volumeMount:**

```yaml
containers:
- name: <container-name>
  volumeMounts:
  - name: data
    mountPath: /home/node/.openclaw
volumes:
- name: data
  persistentVolumeClaim:
    claimName: <workload>-data
```

## Initial WhatsApp Pairing

**Prerequisites:**
- WhatsApp enabled in config but pod must NOT be running (auto-connect hangs without credentials)

**Run manually by human:**

```bash
kubectl -n <namespace> exec -it deploy/<workload> -- sh -c 'openclaw config set channels.whatsapp.enabled true && sleep 2 && openclaw channels login --channel whatsapp'
```

Scan QR code with WhatsApp mobile app (Linked Devices) before command timeout.

**Verify pairing:**

```bash
kubectl -n <namespace> exec deploy/<workload> -- openclaw gateway health --json | grep '"linked"'
# Expected: "linked": true
```

**Verify credential persistence:**

```bash
kubectl -n <namespace> exec deploy/<workload> -- find /home/node/.openclaw/credentials/whatsapp/<account-id>/ -type f | wc -l
# Expected: ~800+ files
```

## Health Check Pattern

**Run manually by human:**

```bash
kubectl -n <namespace> exec deploy/<workload> -- openclaw gateway health --json
```

**Key status fields:**

- `channels.whatsapp.linked`: true = credentials present and valid
- `channels.whatsapp.running`: true = channel process active
- `channels.whatsapp.connected`: true = connected to WhatsApp servers
- `channels.whatsapp.self.e164`: linked phone number

**Note:** Health check may lag actual connection state. Test functionality by sending a WhatsApp message.

## Persistence Validation

**Full pod restart test:**

```bash
kubectl -n <namespace> delete pod -l app=<workload>
kubectl -n <namespace> wait --for=condition=ready pod -l app=<workload> --timeout=2m
```

**Verify auto-reconnect:**

```bash
kubectl -n <namespace> exec deploy/<workload> -- openclaw gateway health --json | grep -E '"linked"|"running"|"connected"'
```

Expected: WhatsApp reconnects automatically using persisted credentials from PVC.

## Recovery Procedures

### Scenario: Credentials Lost (PVC deleted or corrupted)

1. **Disable WhatsApp in source config** to prevent startup hang:
   - Edit source `config/openclaw.json`, set `channels.whatsapp.enabled: false`
   - Commit and push to trigger image rebuild
   - Wait for CI build and image promotion

2. **Delete old PVC** to force fresh config seed:

   **Run manually by human:**
   ```bash
   kubectl -n <namespace> delete pod -l app=<workload>
   kubectl -n <namespace> delete pvc <workload>-data
   ```

3. **Re-pair WhatsApp** (see Initial Pairing section above)

### Scenario: Startup Hang (WhatsApp enabled without credentials)

**Symptoms:** Pod stuck at 0/1 Ready, startupProbe failing, port not listening

**Run manually by human:**

```bash
# Force-delete hanging pod
kubectl -n <namespace> delete pod -l app=<workload> --force --grace-period=0

# Disable WhatsApp on PV (if accessible)
kubectl -n <namespace> exec deploy/<workload> -- sed -i 's/"enabled": true/"enabled": false/' /home/node/.openclaw/openclaw.json
kubectl -n <namespace> delete pod -l app=<workload>
```

If PV inaccessible, follow "Credentials Lost" recovery above.

### Scenario: Connection Drops

**Run manually by human:**

```bash
# Check pod events
kubectl -n <namespace> describe pod -l app=<workload> | tail -30

# Check OpenClaw logs
kubectl -n <namespace> logs -l app=<workload> --tail=100

# Check gateway health
kubectl -n <namespace> exec deploy/<workload> -- openclaw gateway health --json

# Manual reconnect attempt
kubectl -n <namespace> exec deploy/<workload> -- openclaw channels start --channel whatsapp
```

## Operational Constraints

- **Single replica only**: WhatsApp protocol allows one active session per account. Do NOT scale `replicas > 1`.
- **ReadWriteOnce PVC**: Only one pod can mount the data PVC at a time.
- **Auto-connect behavior**: Enabled channels auto-connect on gateway startup (OpenClaw design, not configurable).
- **Startup time**: Allow sufficient time for startup probes (recommend failureThreshold: 90, periodSeconds: 10s = 15min budget).

## Configuration Hotfix Pattern

Changes to `/home/node/.openclaw/openclaw.json` on the PVC propagate faster than image rebuilds (1-2 min vs 15-30 min).

**Run manually by human:**

```bash
kubectl -n <namespace> exec deploy/<workload> -- openclaw config set <key> <value>
# Restart required to apply (requires pod restart in containerized environment)
kubectl -n <namespace> delete pod -l app=<workload>
```

**Note:** PV config changes are ephemeral relative to image. To persist changes long-term, update source config and rebuild image.

## Reference Implementation: mia

- **Namespace:** `mia`
- **Workload:** `mia`
- **PVC:** `mia-data` (1Gi, local-path)
- **Account ID:** `default`
- **Implementation date:** 2026-03-13

**Validation commands:**

```bash
# Check deployment status
kubectl -n mia get deploy,rs,pods

# Check PVC binding
kubectl -n mia get pvc mia-data

# Verify credentials on PV
kubectl -n mia exec deploy/mia -- find /home/node/.openclaw/credentials/whatsapp/default/ -type f | wc -l

# Check WhatsApp config
kubectl -n mia exec deploy/mia -- grep -A10 '"whatsapp"' /home/node/.openclaw/openclaw.json

# Full health check
kubectl -n mia exec deploy/mia -- openclaw gateway health --json
```
