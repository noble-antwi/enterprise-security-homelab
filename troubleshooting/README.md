# 🔧 Troubleshooting Guide

## 📖 Quick Issue Finder

### 🚨 Critical Issues (Immediate Action Required)
- [Lost pfSense Access](network-infrastructure.md#issue-1-lost-administrative-access-after-interface-changes)
- [Complete Tailscale Connectivity Loss](remote-access.md#issue-1-complete-connectivity-loss-after-isp-migration)

### 🌐 Network & Connectivity Issues
- [pfSense Access Problems](network-infrastructure.md#lost-administrative-access-after-interface-changes)
- [ICMP Connectivity Failures](network-infrastructure.md#windows-client-icmp-connectivity-failures)
- [Inter-VLAN Communication](network-infrastructure.md#inter-vlan-communication-challenges)
- [VMware Network Bridge](network-infrastructure.md#vmware-network-bridge-configuration)

### 🌍 Remote Access & VPN
- [ISP Migration Issues](remote-access.md#complete-connectivity-loss-after-isp-migration)

### 🖥️ System Configuration
- [Netplan Gateway Warnings](system-administration.md#netplan-gateway-deprecation-warnings)
- [SSH Authentication Problems](system-administration.md#ssh-host-key-verification-failures)
- [Package Installation Conflicts](system-administration.md#rocky-linux-package-installation-conflicts)

## 🔍 Quick Diagnostic Commands

### Network Troubleshooting
```bash
# Basic connectivity
ping 192.168.10.1
ping 8.8.8.8

# Check routes
ip route show

# Test services
curl -I http://192.168.10.1
```

### Service Health Check
```bash
# Check service status
sudo systemctl status wazuh-manager grafana-server prometheus

# Test Ansible connectivity
ansible all_in_one -m ping
```

### Tailscale Diagnostics
```bash
# Check Tailscale status
tailscale status

# Test mesh connectivity
ping 100.81.37.60
```

## 📚 Documentation by Component

| Component | Troubleshooting Guide | Based on Real Issues |
|-----------|----------------------|---------------------|
| **Network Infrastructure** | [network-infrastructure.md](network-infrastructure.md) | pfSense, VLAN, ICMP issues |
| **Remote Access** | [remote-access.md](remote-access.md) | ISP migration, Tailscale conflicts |
| **System Administration** | [system-administration.md](system-administration.md) | SSH, Netplan, package issues |

## 🎯 How to Use This Guide

### If You're Experiencing...
- **Can't access pfSense** → Start with [Network Infrastructure](network-infrastructure.md)
- **Tailscale not working** → Check [Remote Access](remote-access.md)
- **SSH/service issues** → Review [System Administration](system-administration.md)

---

*Troubleshooting Guide Status: ✅ Based on Real Implementation Experience*