# 🌍 Remote Access & VPN Troubleshooting

## 🌐 Tailscale & Remote Access Issues

### Issue 1: Complete Connectivity Loss After ISP Migration

#### **Problem Description**
After relocating lab infrastructure and changing Internet Service Providers, Tailscale connectivity resulted in complete loss of network access to all lab resources, including local pfSense management and VLAN services.

#### **Symptoms**
- Local access to pfSense web GUI functional when Tailscale disconnected
- **Complete connectivity loss** when connecting to Tailscale mesh VPN
- Unable to access any lab resources (pfSense, Wazuh, Grafana) via Tailscale
- Laptop receives proper DHCP IP (`192.168.10.50`) but cannot route to services
- Internet connectivity works normally without Tailscale

#### **Environmental Context**
- **ISP Migration**: Lab relocated from previous ISP to new provider
- **pfSense WAN IP Change**: `192.168.4.32` → `10.0.0.104`
- **Tailscale Previously Functional**: Remote access worked before relocation
- **Local Network Intact**: All VLAN configurations and services operational

#### **Root Cause Analysis**
The ISP change triggered a **Tailscale device identity conflict**:

1. **pfSense WAN IP changed** during ISP migration
2. **Tailscale re-authentication created new device identity**:
   - **Old pfSense**: `pfsense-homelab` (100.75.180.98) - **OFFLINE**
   - **New pfSense**: `pfsense-homelab-1` (100.81.37.60) - **ONLINE**
3. **Client devices continued routing** through old, offline pfSense instance
4. **Subnet routes not approved** for new pfSense device
5. **Result**: All local traffic routed through broken mesh path

#### **Diagnostic Process**

##### Console Access Investigation
```bash
# SSH to pfSense to check Tailscale status
ssh admin@192.168.10.1

# Check Tailscale service status
/usr/local/bin/tailscale status
# Revealed:
# 100.81.37.60   pfsense-homelab-1    freebsd online
# 100.90.17.43   nantwi-host-laptop   windows offline  
# 100.75.180.98  pfsense-homelab      freebsd offline
```

##### Tailscale Admin Console Analysis
- **Two pfSense devices** present in mesh network
- **Subnet routes approved** only for old, offline device
- **New device** waiting for subnet route approval
- **Client routing table** pointing to offline device

#### **Solution Implementation**

##### Step 1: Tailscale Admin Console Configuration
```
Navigate to: login.tailscale.com/admin

Device Management:
1. Locate "pfsense-homelab-1" (100.81.37.60) - ONLINE
2. Click "Subnets" → Approve all subnet routes:
   ✅ 192.168.10.0/24 (Management)
   ✅ 192.168.20.0/24 (BlueTeam) 
   ✅ 192.168.30.0/24 (RedTeam)
   ✅ 192.168.40.0/24 (DevOps)
   ✅ 192.168.50.0/24 (EnterpriseLAN)
   ✅ 192.168.60.0/24 (Monitoring)

3. Locate "pfsense-homelab" (100.75.180.98) - OFFLINE
4. Disable all subnet routes or delete device entirely
```

##### Step 2: Client Route Refresh
```bash
# Disconnect from Tailscale completely
# Reconnect to Tailscale mesh
# Verify new routing table points to 100.81.37.60
```

##### Step 3: Connectivity Verification
```bash
# Test local access with Tailscale connected
ping 192.168.10.1    # pfSense Management
ping 192.168.20.2    # Wazuh SIEM
ping 192.168.60.2    # Grafana/Prometheus

# Test Tailscale mesh connectivity
ping 100.81.37.60    # New pfSense via mesh
curl http://100.81.37.60  # pfSense GUI via mesh
```

#### **Post-Resolution Validation**
✅ **Local Network Access**: All VLAN resources accessible with Tailscale connected  
✅ **Remote Mesh Access**: Lab accessible from external networks via Tailscale  
✅ **Service Functionality**: pfSense, Wazuh, Grafana operational via both methods  
✅ **Route Optimization**: Traffic routing through correct, online pfSense instance  

#### **Prevention Strategy**

##### Pre-Migration Checklist
- [ ] **Document current Tailscale device IDs** and IP assignments
- [ ] **Backup pfSense Tailscale configuration** 
- [ ] **Note approved subnet routes** in admin console
- [ ] **Plan for potential device re-authentication**

##### Post-Migration Verification
- [ ] **Verify pfSense Tailscale service** operational after WAN IP change
- [ ] **Check for duplicate devices** in Tailscale admin console
- [ ] **Validate subnet routes** approved for correct device
- [ ] **Test both local and remote access** before concluding migration

---

## 🔍 Tailscale Diagnostic Commands

### pfSense-Side Diagnostics
```bash
# SSH to pfSense
ssh admin@192.168.10.1

# Check Tailscale process
ps aux | grep tailscale

# Check Tailscale status
/usr/local/bin/tailscale status

# Restart Tailscale if needed
/usr/local/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &

# Re-authenticate with mesh
/usr/local/bin/tailscale up \
  --advertise-routes=192.168.10.0/24,192.168.20.0/24,192.168.30.0/24,192.168.40.0/24,192.168.50.0/24,192.168.60.0/24 \
  --accept-routes \
  --hostname=pfsense-homelab
```

### Client-Side Diagnostics
```bash
# Check Tailscale status
tailscale status

# Test mesh connectivity
ping 100.81.37.60  # pfSense mesh IP
```

---

## 🚨 Emergency Access Procedures

### Lost Remote Access Recovery
1. **Use local network access** as primary fallback
2. **Physical console access** to pfSense if needed
3. **Check ISP connectivity** and WAN interface status
4. **Verify Tailscale service** running on pfSense
5. **Re-authenticate device** if necessary

### Multiple Access Path Strategy
Always maintain these access methods:
- **Local network access** (primary)
- **Tailscale mesh access** (remote)
- **Physical console access** (emergency)

---

*Remote Access Troubleshooting | Based on Real ISP Migration Experience*