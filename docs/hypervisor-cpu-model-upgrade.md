# Hypervisor CPU Model Upgrade Runbook

**Purpose:** Upgrade libvirt VM CPU model from `qemu64` to `host-passthrough` to enable x86-64-v2 instruction support for KeyCloak, Kiali, Tempo, and improved performance.

**Expected Downtime:** 15-30 minutes
**Execution Environment:** zave-lab hypervisor
**Prerequisites:** Physical access to zave-lab for cleaning

---

## Pre-Maintenance Checklist

- [ ] Verify all critical workloads are in healthy state
- [ ] Notify team of planned maintenance window
- [ ] Ensure SSH access to bastion before shutdown
- [ ] Have console/monitor access available if needed

---

## Step 1: Graceful K3s Cluster Shutdown

**From bastion (k3s-bastion-01):**

```bash
# Drain and cordon worker nodes
kubectl drain k3s-worker-01 --ignore-daemonsets --delete-emptydir-data
kubectl drain k3s-worker-02 --ignore-daemonsets --delete-emptydir-data

# Wait for pods to terminate gracefully
kubectl get pods --all-namespaces -o wide | grep -v "kube-system\|Completed"

# Shutdown worker VMs
ssh ubuntu@k3s-worker-01 'sudo shutdown -h now'
ssh ubuntu@k3s-worker-02 'sudo shutdown -h now'

# Wait 2 minutes for graceful shutdown
sleep 120

# Shutdown control plane
ssh ubuntu@k3s-control-01 'sudo shutdown -h now'

# Wait 2 minutes
sleep 120
```

---

## Step 2: Verify VM Shutdown

**From hypervisor (zave-lab):**

```bash
# Check VM states
sudo virsh list --all

# All k3s VMs should show "shut off"
# Expected output:
# k3s-control-01    shut off
# k3s-worker-01     shut off
# k3s-worker-02     shut off
```

---

## Step 3: Shutdown Hypervisor

**From hypervisor (zave-lab):**

```bash
# Verify no other critical VMs are running
sudo virsh list --all

# Shutdown hypervisor
sudo shutdown -h now
```

---

## Step 4: Physical Maintenance

**Physical access required:**

- [ ] Open case/enclosure
- [ ] Use compressed air to clean:
  - CPU heatsink fins
  - All case fans (intake and exhaust)
  - Dust filters
  - Power supply fan
  - RAM slots and PCIe slots
- [ ] Verify all fan cables are secure
- [ ] Check for any physical obstructions to airflow
- [ ] Optional: Replace thermal paste if >2 years old
  - Document if repasting was performed
- [ ] Close case/enclosure

---

## Step 5: Power On and Boot Hypervisor

**Physical access:**

- [ ] Power on zave-lab
- [ ] Wait for boot (monitor via console or SSH)
- [ ] Verify SSH access: `ssh xlopez@zave-lab`

**From workstation:**

```bash
# Wait for hypervisor to boot
ssh xlopez@zave-lab 'uptime'

# Check libvirtd service
ssh xlopez@zave-lab 'sudo systemctl status libvirtd'
```

---

## Step 6: Backup Current VM Configurations

**From hypervisor (zave-lab):**

```bash
# Create backup directory
mkdir -p ~/vm-configs-backup-$(date +%Y%m%d)
cd ~/vm-configs-backup-$(date +%Y%m%d)

# Backup current VM XML configs
sudo virsh dumpxml k3s-control-01 > k3s-control-01.xml
sudo virsh dumpxml k3s-worker-01 > k3s-worker-01.xml
sudo virsh dumpxml k3s-worker-02 > k3s-worker-02.xml

# Verify backups
ls -lh *.xml
```

---

## Step 7: Update CPU Model for Each VM

**From hypervisor (zave-lab):**

### Update k3s-control-01

```bash
sudo virsh edit k3s-control-01
```

**Find this section:**
```xml
<cpu mode='custom' match='exact' check='full'>
  <model fallback='forbid'>qemu64</model>
  <feature policy='require' name='x2apic'/>
  <feature policy='require' name='hypervisor'/>
  <feature policy='require' name='lahf_lm'/>
  <feature policy='disable' name='svm'/>
</cpu>
```

**Replace with:**
```xml
<cpu mode='host-passthrough' check='none'>
  <topology sockets='1' dies='1' cores='2' threads='1'/>
</cpu>
```

**Save and exit:** `:wq`

### Update k3s-worker-01

```bash
sudo virsh edit k3s-worker-01
```

**Apply same CPU configuration change, save and exit.**

### Update k3s-worker-02

```bash
sudo virsh edit k3s-worker-02
```

**Apply same CPU configuration change, save and exit.**

---

## Step 8: Start VMs and Verify Boot

**From hypervisor (zave-lab):**

```bash
# Start control plane first
sudo virsh start k3s-control-01

# Wait 30 seconds
sleep 30

# Start workers
sudo virsh start k3s-worker-01
sudo virsh start k3s-worker-02

# Check VM states
sudo virsh list --all

# All should show "running"
```

---

## Step 9: Verify SSH and CPU Features

**From hypervisor (zave-lab):**

```bash
# Wait for SSH to be available (2-3 minutes)
sleep 120

# Test SSH connectivity
ssh ubuntu@k3s-control-01 'uptime'
ssh ubuntu@k3s-worker-01 'uptime'
ssh ubuntu@k3s-worker-02 'uptime'

# Verify x86-64-v2 CPU features are present
ssh ubuntu@k3s-worker-01 'lscpu | grep Flags'

# Should see: sse4_1, sse4_2, ssse3, popcnt, cx16
ssh ubuntu@k3s-worker-01 'grep -E "sse4_1|sse4_2|ssse3|popcnt" /proc/cpuinfo | head -1'
```

**Expected output:** Should see all x86-64-v2 required flags

---

## Step 10: Verify K3s Cluster Health

**From bastion (k3s-bastion-01):**

```bash
# Wait for K3s to stabilize (5-10 minutes)
kubectl get nodes

# All nodes should show Ready
# NAME              STATUS   ROLES                  AGE   VERSION
# k3s-control-01    Ready    control-plane,master   Xd    v1.X.X
# k3s-worker-01     Ready    <none>                 Xd    v1.X.X
# k3s-worker-02     Ready    <none>                 Xd    v1.X.X

# Uncordon worker nodes
kubectl uncordon k3s-worker-01
kubectl uncordon k3s-worker-02

# Check pod status
kubectl get pods --all-namespaces | grep -v "Running\|Completed"

# Wait for all pods to be Running (may take 5-15 minutes)
kubectl get pods -n bigbang -w
```

---

## Step 11: Monitor Temperatures Post-Change

**From hypervisor (zave-lab):**

```bash
# Monitor CPU temperature
watch -n 5 'sensors | grep -E "Core|Package"'

# Monitor system load
watch -n 5 'uptime'

# Monitor VM CPU usage
watch -n 5 'top -bn1 | head -15'
```

**Target metrics:**
- Idle temperature: <60°C
- Load temperature: <85°C (was 89°C before)
- Load average: Should be similar or lower than before

**Monitor for 15-30 minutes to establish baseline.**

---

## Step 12: Deploy KeyCloak

**From workstation:**

KeyCloak deployment should now succeed with x86-64-v2 CPU support.

```bash
# Verify KeyCloak pods are running
kubectl get pods -n keycloak

# Check KeyCloak logs (should not show "CPU does not support x86-64-v2" error)
kubectl logs -n keycloak keycloak-keycloak-0 -c keycloak --tail=50

# Monitor KeyCloak deployment
kubectl get helmrelease -n bigbang keycloak -w
```

---

## Step 13: Post-Maintenance Verification

**Checklist:**

- [ ] All K3s nodes are Ready
- [ ] All critical pods are Running
- [ ] No crash loops or errors in pod logs
- [ ] KeyCloak pods are running without x86-64-v2 errors
- [ ] Hypervisor temperature is <85°C under load
- [ ] No unusual errors in `dmesg` on VMs
- [ ] Network connectivity verified (ping, curl tests)
- [ ] Flux reconciliation working (check kustomizations)

**From bastion:**

```bash
# Full cluster health check
kubectl get nodes
kubectl get pods --all-namespaces | grep -v "Running\|Completed"
kubectl get kustomizations -n flux-system
kubectl get helmreleases -n bigbang

# Test a sample workload
kubectl run test-nginx --image=nginx:alpine --rm -it --restart=Never -- echo "Test successful"
```

---

## Rollback Procedure (If Needed)

**If temperatures exceed 95°C or system is unstable:**

1. **Shutdown VMs:**
   ```bash
   sudo virsh shutdown k3s-control-01
   sudo virsh shutdown k3s-worker-01
   sudo virsh shutdown k3s-worker-02
   ```

2. **Restore original CPU configs:**
   ```bash
   cd ~/vm-configs-backup-YYYYMMDD/
   sudo virsh define k3s-control-01.xml
   sudo virsh define k3s-worker-01.xml
   sudo virsh define k3s-worker-02.xml
   ```

3. **Restart VMs:**
   ```bash
   sudo virsh start k3s-control-01
   sleep 30
   sudo virsh start k3s-worker-01
   sudo virsh start k3s-worker-02
   ```

4. **Address root cause** (cooling, workload optimization) before retrying

---

## Success Criteria

- [ ] All VMs boot successfully with host-passthrough CPU
- [ ] x86-64-v2 CPU features confirmed in guest OS
- [ ] K3s cluster fully healthy
- [ ] KeyCloak deploys without CPU compatibility errors
- [ ] Hypervisor temperature stable at <85°C
- [ ] No performance degradation or new errors

---

## Notes

**Date Executed:** _____________
**Executed By:** _____________
**Actual Downtime:** _____________
**Temperature Before:** 89°C under load
**Temperature After:** _____________
**Issues Encountered:** _____________
**Deviations from Plan:** _____________

---

## Related Documentation

- `platform-docs/_platform/EXECUTION_ENVIRONMENTS.md` - Execution environment taxonomy
- `docs/vault-migration-plan.md` - Vault configuration and policies
- BigBang values: `bigbang/values.yaml` - KeyCloak configuration
