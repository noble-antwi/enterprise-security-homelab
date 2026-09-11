# Troubleshooting Guide

## Quick Issue Finder

### Critical Issues (Immediate Action Required)
- [Lost pfSense Access](network_infrastructure.md#issue-1-lost-administrative-access-after-interface-changes)
- [Complete Tailscale Connectivity Loss](remote_access.md#issue-1-complete-connectivity-loss-after-isp-migration)

### Network & Connectivity Issues
- [pfSense Access Problems](network_infrastructure.md#lost-administrative-access-after-interface-changes)
- [ICMP Connectivity Failures](network_infrastructure.md#windows-client-icmp-connectivity-failures)
- [Inter-VLAN Communication](network_infrastructure.md#inter-vlan-communication-challenges)
- [VMware Network Bridge](network_infrastructure.md#vmware-network-bridge-configuration)

### Remote Access & VPN
- [ISP Migration Issues](remote_access.md#complete-connectivity-loss-after-isp-migration)

### System Configuration
- [Netplan Gateway Warnings](system_admin.md#netplan-gateway-deprecation-warnings)
- [SSH Authentication Problems](system_admin.md#ssh-host-key-verification-failures)
- [Package Installation Conflicts](system_admin.md#rocky-linux-package-installation-conflicts)

### Windows Integration
- [WinRM Connection Timeouts](windows-integration.md#issue-1-winrm-connection-timeouts)
- [Python Package Installation](windows-integration.md#issue-2-python-package-installation-for-windows-support)
- [Windows User Account Creation](windows-integration.md#issue-3-windows-user-account-creation-methods)
- [Cross-Platform Module Conflicts](windows-integration.md#issue-6-cross-platform-module-conflicts)

## Quick Diagnostic Commands

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

## Documentation by Component

| Component | Troubleshooting Guide | Based on Real Issues |
|-----------|----------------------|---------------------|
| **Network Infrastructure** | [network_infrastructure.md](network_infrastructure.md) | pfSense, VLAN, ICMP issues |
| **Remote Access** | [remote_access.md](remote_access.md) | ISP migration, Tailscale conflicts |
| **System Administration** | [system_admin.md](system_admin.md) | SSH, Netplan, package issues |
| **Windows Integration** | [windows-integration.md](windows-integration.md) | WinRM, Python packages, account creation |
| **Ansible Automation** | [ansible-automation.md](ansible-automation.md) | Inventory, connectivity, module issues |

## How to Use This Guide

### If You're Experiencing...
- **Can't access pfSense**: Start with [Network Infrastructure](network_infrastructure.md)
- **Tailscale not working**: Check [Remote Access](remote_access.md)
- **SSH/service issues**: Review [System Administration](system_admin.md)

