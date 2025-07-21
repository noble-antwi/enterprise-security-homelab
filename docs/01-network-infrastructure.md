# Network Infrastructure & pfSense Configuration

## 📖 Overview

This document details the complete network infrastructure setup using **pfSense** as the core firewall and routing platform, implementing enterprise-grade **VLAN segmentation** with a **TP-Link TL-SG108E managed switch**. The architecture provides isolated network segments for different security functions while maintaining centralized control and monitoring.

## 💻 Hardware Architecture

### Core Components
- **pfSense Firewall**: Dedicated desktop machine with 2 NICs
- **TP-Link TL-SG108E**: 8-Port Gigabit Smart Managed Switch
- **Primary Laptop**: Administrative access and VM host (2 NICs)
- **Additional Systems**: Reserved for service deployment

### Physical Topology

```
Internet ↔ Home Router ↔ pfSense (WAN/LAN) ↔ Managed Switch ↔ VLAN Segments
                                    ↕
                            All Lab Infrastructure
```

## 🔧 pfSense Configuration

### Interface Configuration

#### Base Interface Changes
- **Default LAN (ue0)**: Changed from `192.168.1.1` to `192.168.99.1`
- **Isolation Applied**: No DHCP, blocked traffic for security
- **VLAN Parent**: All VLANs created under interface `ue0`
- **WAN Interface**: Maintains connection to upstream router

#### Interface Assignment Summary
| Interface | Type | Purpose | IP Address |
|-----------|------|---------|------------|
| **WAN** | Physical | Internet connectivity | DHCP from ISP |
| **LAN (ue0)** | Physical | VLAN parent interface | `192.168.99.1` (isolated) |
| **VLAN 10** | Virtual | Management access | `192.168.10.1` |
| **VLAN 20** | Virtual | BlueTeam security | `192.168.20.1` |
| **VLAN 30** | Virtual | RedTeam operations | `192.168.30.1` |
| **VLAN 40** | Virtual | DevOps pipeline | `192.168.40.1` |
| **VLAN 50** | Virtual | EnterpriseLAN | `192.168.50.1` |
| **VLAN 60** | Virtual | Monitoring stack | `192.168.60.1` |

## 🧱 VLAN & Subnet Architecture

### Design Philosophy
The network implements **VLAN-based segmentation** where each VLAN represents a separate logical security zone. This approach ensures:
- **Layer 2 isolation** between different environments
- **Granular firewall control** via pfSense rules
- **Enhanced monitoring** and policy enforcement
- **Clear separation** between Blue Team and Red Team activities

### Complete VLAN Specification

| **VLAN Name** | **VLAN ID** | **Subnet** | **Gateway IP** | **Purpose & Use Case** |
|---------------|-------------|------------|----------------|------------------------|
| **Management** | `10` | `192.168.10.0/24` | `192.168.10.1` | Administrative access to pfSense Web UI and management systems. Restricted to trusted admin devices only. |
| **BlueTeam** | `20` | `192.168.20.0/24` | `192.168.20.1` | Security monitoring infrastructure including Wazuh SIEM, ELK stack, IDS sensors, and defense tools. |
| **RedTeam** | `30` | `192.168.30.0/24` | `192.168.30.1` | Isolated environment for attack simulation, penetration testing, and offensive security experiments. |
| **DevOps** | `40` | `192.168.40.0/24` | `192.168.40.1` | CI/CD infrastructure, build servers, deployment automation, and DevSecOps toolchain. |
| **EnterpriseLAN** | `50` | `192.168.50.0/24` | `192.168.50.1` | Simulated business services including internal DNS, web applications, and corporate server infrastructure. |
| **Monitoring** | `60` | `192.168.60.0/24` | `192.168.60.1` | Dedicated observability stack hosting Prometheus, Grafana, Loki, and out-of-band monitoring systems. |

### Network Segmentation Benefits
- 🔐 **Enhanced Security**: Layer 2 isolation with pfSense firewall control
- 🔍 **Clear Visibility**: Each team/function has dedicated network space
- 🧪 **Safe Testing**: Attack simulations contained within RedTeam VLAN
- 📊 **Monitoring**: Centralized observability without network interference

## 🗂️ DHCP Configuration Strategy

### IP Address Allocation Plan
Each VLAN subnet uses a structured IP allocation to prevent conflicts and ensure predictable addressing:

- **Static Range**: `.2` through `.49` (48 addresses for servers/infrastructure)
- **DHCP Pool**: `.50` through `.100` (51 addresses for dynamic assignment)
- **Reserved**: `.101` through `.254` (154 addresses for future expansion)

### DHCP Scope Configuration

#### Example: Management VLAN (192.168.10.0/24)
- **Static Assignments**: `192.168.10.2` – `192.168.10.49`
- **DHCP Dynamic Pool**: `192.168.10.50` – `192.168.10.100`
- **Future Use**: `192.168.10.101` – `192.168.10.254`

*This pattern is replicated across all VLANs for consistency.*

### DHCP Implementation Evidence

#### Management VLAN DHCP Configuration
![DHCP Configuration for Management VLAN](image-2.png)

#### BlueTeam VLAN DHCP Configuration  
![DHCP Configuration for BlueTeam VLAN](image-3.png)

### Strategic Benefits
✅ **Predictable Infrastructure**: Critical systems use static IPs  
✅ **Conflict Prevention**: Clear separation between static and dynamic ranges  
✅ **Scalability**: Significant room for future growth  
✅ **Consistency**: Identical pattern across all VLANs  

## 🔥 Firewall Rules & Access Control

### Security Model
pfSense implements a **default-deny** security model where all traffic is blocked unless explicitly allowed. Each VLAN has customized firewall rules based on its security requirements and operational needs.

### Management VLAN (VLAN 10) Rules

| Action | Protocol | Source | Destination | Purpose |
|--------|----------|--------|-------------|---------|
| ✅ **Allow** | ICMP | VLAN 10 Subnet | Any | Network troubleshooting and connectivity testing |
| ✅ **Allow** | TCP/UDP | VLAN 10 Subnet | This Firewall | Access to pfSense Web UI (HTTPS) |
| ✅ **Allow** | UDP | VLAN 10 Subnet | Any (Port 53) | DNS resolution services |
| ✅ **Allow** | Any | VLAN 10 Subnet | Any | Full internet access for administrative tasks |

#### Management VLAN Firewall Implementation
![Management VLAN Firewall Rules](image-4.png)

### Other VLANs Security Rules

For **BlueTeam, RedTeam, DevOps, EnterpriseLAN, and Monitoring** VLANs:

| Action | Protocol | Source | Destination | Purpose |
|--------|----------|--------|-------------|---------|
| ✅ **Allow** | Any | VLAN [X] Subnet | Any | Full internet access for operational requirements |

#### Additional VLANs Firewall Configuration
![Other Firewall Rules](image-5.png)

### Firewall Rule Strategy
- **Management VLAN**: Most permissive with administrative access
- **Operational VLANs**: Internet access with potential for future restrictions
- **Inter-VLAN Communication**: Controlled by specific rules as needed
- **Default Behavior**: All traffic denied unless explicitly permitted

## 🌍 Outbound NAT Configuration

### NAT Implementation Approach
To enable proper internet connectivity for all VLAN segments, pfSense uses **Hybrid Outbound NAT** mode, providing explicit control over network address translation while maintaining automatic rule generation for standard interfaces.

### Configuration Method
1. **Mode Selection**: **Firewall > NAT > Outbound**
2. **Mode Change**: Switched to **"Hybrid Outbound NAT rule generation"**
3. **Rule Creation**: Manual rules defined for each VLAN subnet

### NAT Rule Specification

| VLAN Name | Source Subnet | Translation Target | Status |
|-----------|---------------|-------------------|--------|
| **Management** | `192.168.10.0/24` | WAN Interface | ✅ Active |
| **BlueTeam** | `192.168.20.0/24` | WAN Interface | ✅ Active |
| **RedTeam** | `192.168.30.0/24` | WAN Interface | ✅ Active |
| **DevOps** | `192.168.40.0/24` | WAN Interface | ✅ Active |
| **EnterpriseLAN** | `192.168.50.0/24` | WAN Interface | ✅ Active |
| **Monitoring** | `192.168.60.0/24` | WAN Interface | ✅ Active |

#### Hybrid Outbound NAT Configuration
![Hybrid Outbound NAT](image-6.png)

### Hybrid NAT Advantages
✅ **Flexibility**: Manual control over VLAN-specific NAT behavior  
✅ **Compatibility**: Retains pfSense default rules for other interfaces  
✅ **Scalability**: Easy to modify or restrict specific VLANs  
✅ **Visibility**: Clear understanding of NAT translations  

## 🔌 Switch Port Configuration

### TP-Link TL-SG108E Port Mapping
The managed switch provides VLAN segmentation through strategic port assignments, supporting both trunk and access port configurations.

| **Port** | **Configuration** | **VLAN Membership** | **Purpose** |
|----------|-------------------|---------------------|-------------|
| **Port 1** | Trunk (Tagged) | **All VLANs**: 10,20,30,40,50,60 | pfSense `ue0` interface connection |
| **Port 2** | Trunk (Tagged) | **All VLANs**: 10,20,30,40,50,60 | Laptop USB NIC for VM management |
| **Port 3** | Access (Untagged) | **VLAN 10 Only** | Management VLAN direct access |
| **Port 4** | Access (Untagged) | **VLAN 20 Only** | BlueTeam VLAN direct access |
| **Port 5** | Access (Untagged) | **VLAN 30 Only** | RedTeam VLAN direct access |
| **Port 6** | Access (Untagged) | **VLAN 40 Only** | DevOps VLAN direct access |
| **Port 7** | Access (Untagged) | **VLAN 50 Only** | EnterpriseLAN VLAN direct access |
| **Port 8** | Access (Untagged) | **VLAN 60 Only** | Monitoring VLAN direct access |

#### Switch Port Configuration Evidence
![Port Configuration in Switch](image.png)
![Port Configuration in Switch - Details](image-1.png)

### Port Configuration Strategy
- **Trunk Ports (1-2)**: Carry all VLAN traffic for infrastructure and management
- **Access Ports (3-8)**: Provide direct, untagged access to specific VLANs
- **Device Placement**: End devices automatically assigned to appropriate VLAN
- **Scalability**: Additional devices easily added to any VLAN segment

## 🔒 Security Implementation

### Network Security Measures
- **LAN Interface Isolation**: Original `ue0` interface secured with no DHCP or routing
- **Administrative Access Control**: All pfSense GUI access restricted to Management VLAN
- **Inter-VLAN Security**: No default communication between VLANs
- **Controlled Connectivity**: ICMP enabled only for troubleshooting purposes

### Access Control Summary
- **pfSense Management**: Only accessible via `http://192.168.10.1` on VLAN 10
- **VLAN Isolation**: Each VLAN operates independently unless rules permit interaction
- **Firewall Protection**: All traffic subject to pfSense security rules
- **Default Deny**: Implicit denial of all traffic not explicitly permitted

## 🐛 Implementation Challenges & Solutions

### Key Issues Resolved

#### Issue 1: Lost Administrative Access
**Problem**: Disabling original LAN interface caused loss of pfSense access  
**Solution**: Assigned fallback IP and implemented blocking instead of disabling  
**Lesson**: Always maintain administrative access during network changes  

#### Issue 2: Windows Client Connectivity
**Problem**: Windows clients unable to ping across VLANs  
**Solution**: Enabled ICMP Echo in pfSense firewall rules  
**Resolution**: Network troubleshooting capabilities restored  

#### Issue 3: Internal vs External Connectivity
**Problem**: External connectivity worked (8.8.8.8) but internal failed  
**Root Cause**: Local firewall rules blocking internal VLAN communication  
**Fix**: Adjusted firewall rules for appropriate inter-VLAN access  

#### Issue 4: GUI Access Verification
**Problem**: Uncertainty about pfSense management access  
**Verification**: Confirmed GUI accessible via `http://192.168.10.1` on VLAN 10  
**Result**: Administrative access properly secured and functional  

## ✅ Implementation Verification

### Network Connectivity Tests
- **VLAN Gateway Access**: All VLANs can reach their respective gateways
- **Internet Connectivity**: Outbound NAT functional for all segments  
- **DNS Resolution**: Name resolution working across all VLANs
- **Administrative Access**: pfSense GUI accessible from Management VLAN

### Security Verification
- **VLAN Isolation**: Confirmed separation between network segments
- **Firewall Rules**: All configured rules operational and effective
- **Access Controls**: Administrative functions properly restricted
- **NAT Translation**: Proper address translation for internet access

## 🚀 Next Phase Integration

### Prepared Infrastructure
The network foundation now supports:
- **Security Services**: SIEM deployment in BlueTeam VLAN
- **Monitoring Systems**: Observability stack in Monitoring VLAN
- **Automation Platforms**: Ansible controller in Management VLAN
- **Testing Environments**: Red Team tools in isolated RedTeam VLAN

### Expansion Capabilities
- Additional VLANs easily configured
- Scalable DHCP and firewall rule management
- Support for complex inter-VLAN communication requirements
- Ready for enterprise service deployment

---

*Network Infrastructure Status: ✅ Complete and Operational*  
*Next Phase: [Security Monitoring Stack Deployment](02-security-monitoring.md)*