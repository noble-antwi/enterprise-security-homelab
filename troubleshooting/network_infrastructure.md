# 🌐 Network Infrastructure Troubleshooting

## 🔥 pfSense & Network Infrastructure Issues

### Issue 1: Lost Administrative Access After Interface Changes

#### **Problem Description**
After disabling the original LAN interface (`ue0`) on pfSense, complete administrative access was lost, preventing further configuration.

#### **Symptoms**
- pfSense Web GUI inaccessible from any network segment
- SSH access non-functional
- No method to access firewall configuration

#### **Root Cause**
Disabling the LAN interface removed the primary administrative access path without establishing an alternative access method.

#### **Solution Implemented**
```bash
# Emergency Recovery Method:
1. Physical console access to pfSense system
2. Reset interface configuration via console menu
3. Assign fallback IP address instead of disabling interface
4. Configure blocking rules instead of interface disabling
```

#### **Prevention Strategy**
✅ **Always maintain administrative access** during network changes  
✅ **Configure alternative access methods** before removing primary access  
✅ **Use blocking rules** instead of disabling interfaces  
✅ **Test changes in stages** rather than making multiple simultaneous changes  

#### **Current Implementation**
- LAN interface assigned `192.168.99.1` and isolated via firewall rules
- Management VLAN (VLAN 10) provides dedicated administrative access
- Multiple access paths available (console, SSH, Web GUI)

---

### Issue 2: Windows Client ICMP Connectivity Failures

#### **Problem Description**
Windows clients on various VLANs unable to ping network resources, including gateways and other systems.

#### **Symptoms**
- `ping` commands to local gateway failed
- `ping` to external addresses (8.8.8.8) successful
- Inconsistent connectivity behavior

#### **Root Cause**
pfSense firewall rules were blocking ICMP traffic by default, preventing ping functionality for network troubleshooting.

#### **Solution Implemented**
```
Firewall > Rules > [VLAN_NAME]:
- Added rule: Allow ICMP from VLAN subnet to Any
- Applied rules and verified functionality
- Tested from multiple VLAN segments
```

#### **Verification Process**
```bash
# Test connectivity from each VLAN
ping 192.168.10.1  # Management gateway - SUCCESS
ping 192.168.20.1  # BlueTeam gateway - SUCCESS  
ping 192.168.60.1  # Monitoring gateway - SUCCESS
ping 8.8.8.8       # External connectivity - SUCCESS
```

---

### Issue 3: Inter-VLAN Communication Challenges

#### **Problem Description**
Systems could reach external resources (internet) but failed to communicate with systems in other VLANs, impacting administrative access and monitoring.

#### **Symptoms**
- External connectivity functional (ping 8.8.8.8 successful)
- Inter-VLAN communication blocked
- Administrative access to monitoring systems failed

#### **Root Cause**
pfSense default-deny security model blocked all inter-VLAN communication unless explicitly permitted by firewall rules.

#### **Solution Process**
```
1. Identified required communication paths:
   - Management VLAN → Monitoring VLAN (administrative access)
   - Management VLAN → BlueTeam VLAN (SIEM management)
   - Monitoring VLAN → All VLANs (metrics collection)

2. Created specific firewall rules:
   - Management VLAN: Allow to Monitoring VLAN subnet
   - Management VLAN: Allow to BlueTeam VLAN subnet  
   - Monitoring VLAN: Allow to Management VLAN subnet

3. Applied and tested rules systematically
```

#### **Validation Testing**
```bash
# From Management VLAN (192.168.10.2):
ssh nantwi@192.168.20.2  # Wazuh server - SUCCESS
ssh nantwi@192.168.60.2  # Monitoring server - SUCCESS

# From Monitoring VLAN (192.168.60.2):
ping 192.168.10.1        # Management gateway - SUCCESS
```

---

### Issue 4: VMware Network Bridge Configuration

#### **Problem Description**
Initial VMware network configuration resulted in VM isolation from the desired VLAN, preventing proper lab integration.

#### **Symptoms**
- VM receiving IP from wrong DHCP scope
- Unable to communicate with VLAN-specific resources
- Inconsistent network behavior

#### **Root Cause Analysis**
VMware was using default bridged networking instead of specific adapter bridging, causing the VM to connect to the wrong network segment.

#### **Solution Implementation**
```
VMware Workstation Pro Configuration:
1. Edit → Virtual Network Editor
2. Create new bridged network: "Mgmt VLAN"
3. Bridge specifically to "Dell Gigabit Ethernet" adapter
4. Disable VMware DHCP for this network
5. Assign VM to "Mgmt VLAN" (VMnet4)
6. Restart VM networking
```

#### **Verification Process**
```bash
# Verify correct IP range assignment
ip addr show
# Expected: 192.168.10.x (Management VLAN range)

# Test VLAN-specific connectivity
ping 192.168.10.1  # Management gateway
```

---

## 🚨 Emergency Network Recovery

### Lost pfSense Access Recovery
1. **Physical console access** to pfSense system
2. **Console menu navigation** to interface configuration
3. **Reset interface** to known working state
4. **Assign temporary IP** for emergency access
5. **Restore proper configuration** via web interface

### VLAN Connectivity Issues
1. **Verify physical connections** and port assignments
2. **Check switch VLAN configuration** for proper memberships
3. **Validate pfSense VLAN definitions** and interface assignments
4. **Test connectivity** at each network layer
5. **Review firewall rules** for blocking conditions

---

*Network Infrastructure Troubleshooting | Based on Real Implementation Issues*