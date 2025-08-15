# Windows Integration with Ansible

## 📖 Overview

This document details the integration of Windows hosts into the existing Ansible automation platform, enabling unified cross-platform management across Linux and Windows systems. The implementation demonstrates the evolution from Linux-only automation to comprehensive enterprise-grade hybrid environment management.

## 🎯 Implementation Summary

### What Was Achieved
- ✅ **Windows Host Added**: 192.168.10.3 successfully integrated into Management VLAN
- ✅ **WinRM Configuration**: Windows Remote Management properly configured for automation
- ✅ **Authentication Setup**: Dedicated `ansible` user created on Windows with administrator privileges
- ✅ **Firewall Configuration**: Windows Firewall rules configured for WinRM external access
- ✅ **Cross-Platform Testing**: Unified automation across all 5 systems (4 Linux + 1 Windows)
- ✅ **Group Variables**: Clean configuration management using Ansible group variables

### Target Architecture
```
Ansible Controller (192.168.10.2)
├── Linux Infrastructure (SSH + ansible service account)
│   ├── 192.168.20.2 (Wazuh SIEM - Rocky Linux)
│   ├── 192.168.60.2 (Monitoring - Ubuntu)
│   ├── 192.168.10.4 (TCM Ubuntu)
│   └── 192.168.10.2 (Controller - Ubuntu)
└── Windows Infrastructure (WinRM + ansible user)
    └── 192.168.10.3 (Windows 11 Pro Host)
```

## 🖥️ Windows Configuration Process

### Step 1: PowerShell Execution Policy
```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
```

### Step 2: WinRM Service Configuration
```powershell
# Configure WinRM for Ansible management
winrm quickconfig -force

# Enable basic authentication
winrm set winrm/config/service/auth '@{Basic="true"}'

# Allow unencrypted traffic
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Configure client authentication
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'

# Restart WinRM service
Restart-Service WinRM
```

### Step 3: User Account Creation
Created dedicated ansible user account:
- **Username**: ansible
- **Password**: AnsiblePass123!
- **Group**: Administrators
- **Properties**: Password never expires

#### User Creation Methods
**Method 1: Windows 11 Settings (Recommended)**
1. Press Win + I (Settings)
2. Click "Accounts" → "Other users"
3. Click "Add account" → "I don't have this person's sign-in information"
4. Click "Add a user without a Microsoft account"
5. Fill in credentials and set as Administrator

**Method 2: PowerShell Command Line**
```powershell
# Create new local user
net user ansible AnsiblePass123! /add

# Add to administrators group
net localgroup administrators ansible /add

# Set password to never expire
wmic useraccount where "Name='ansible'" set PasswordExpires=FALSE
```

### Step 4: Windows Firewall Configuration
The critical missing piece for external connectivity:

```powershell
# Create firewall rule for WinRM
New-NetFirewallRule -DisplayName "WinRM HTTP In" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow
```

**This step was essential** - without it, Ansible could not connect from external networks despite WinRM being properly configured.

## ⚙️ Ansible Configuration Updates

### Controller Preparation
```bash
# Install Windows support on Ubuntu
sudo apt install python3-winrm

# Alternative method if system packages not available
pip3 install pywinrm --break-system-packages
```

### Inventory Configuration

#### Group Variables Approach (Recommended)
Created `/etc/ansible/group_vars/windows.yml`:

```yaml
---
ansible_connection: winrm
ansible_winrm_transport: basic
ansible_winrm_server_cert_validation: ignore
ansible_user: ansible
ansible_password: AnsiblePass123!
ansible_port: 5985
ansible_winrm_scheme: http
```

#### Updated Hosts File
```ini
# Windows systems
[windows]
192.168.10.3

# Combined groups  
[all_systems:children]
all_in_one
windows
```

## 🧪 Testing and Validation

### Connectivity Testing
```bash
# Test Windows connectivity
ansible windows -m win_ping
# Expected: SUCCESS => {"changed": false, "ping": "pong"}

# Test all systems
ansible all_systems -m ping
# Note: Requires cross-platform playbook for mixed environments
```

### Cross-Platform Automation
```bash
# Linux systems use 'ping' module
ansible all_in_one -m ping

# Windows systems use 'win_ping' module  
ansible windows -m win_ping

# Cross-platform playbook execution
ansible-playbook playbooks/ping_all_systems.yml
```

## 🔧 Cross-Platform Playbook Implementation

### Challenge: Mixed Module Requirements
When using `ansible all_systems -m ping`, Windows systems fail because they require the `win_ping` module instead of the standard `ping` module.

### Solution: Conditional Playbook
Created `playbooks/ping_all_systems.yml`:

```yaml
---
- name: Ping All Systems (Cross-Platform)
  hosts: all_systems
  gather_facts: true
  tasks:
    # Linux systems
    - name: Ping Linux systems
      ping:
      when: ansible_os_family != "Windows"
      
    # Windows systems  
    - name: Ping Windows systems
      win_ping:
      when: ansible_os_family == "Windows"
```

**Note**: `gather_facts: true` is essential for `ansible_os_family` variable detection.

## 🛠️ Troubleshooting Journey

### Issue 1: Connection Timeout
**Problem**: HTTPSConnectionPool connection failures
**Root Cause**: Windows Firewall blocking external WinRM connections
**Solution**: Added firewall rule for port 5985

### Issue 2: PowerShell Execution Errors
**Problem**: PowerShell script execution failures in mixed environment
**Root Cause**: PowerShell execution policy restrictions
**Solution**: Set execution policy to RemoteSigned

### Issue 3: Module Selection for Mixed Environments
**Problem**: Cannot use single module command for mixed OS environments
**Solution**: Use platform-specific commands or conditional playbooks

## 📊 Current Infrastructure Status

### Infrastructure Summary
- **Total Managed Systems**: 5 systems
- **Linux Systems**: 4 (Ubuntu + Rocky Linux)
- **Windows Systems**: 1 (Windows 11 Pro)
- **Automation Method**: Unified Ansible platform
- **Authentication**: Platform-specific (SSH for Linux, WinRM for Windows)

### System Inventory
| System | IP Address | OS | Connection | Authentication | Status |
|--------|------------|----|-----------| --------------|--------|
| Ansible Controller | 192.168.10.2 | Ubuntu 24.04 | SSH | ansible service account | 🟢 Active |
| TCM Ubuntu | 192.168.10.4 | Ubuntu 24.04 | SSH | ansible service account | 🟢 Active |
| Wazuh SIEM | 192.168.20.2 | Rocky Linux 9.6 | SSH | ansible service account | 🟢 Active |
| Monitoring Server | 192.168.60.2 | Ubuntu 24.04 | SSH | ansible service account | 🟢 Active |
| **Windows Host** | **192.168.10.3** | **Windows 11 Pro** | **WinRM** | **ansible user** | **🟢 Active** |

### Operational Capabilities
✅ **Unified Management**: Single Ansible controller manages mixed environment  
✅ **Cross-Platform Playbooks**: Conditional logic for OS-specific tasks  
✅ **Service Management**: Control services across all platforms  
✅ **Software Deployment**: Install packages on Linux and Windows  
✅ **Configuration Management**: Deploy configurations to all systems  

## 🔐 Security Implementation

### Authentication Methods
- **Linux Systems**: SSH key-based authentication with dedicated service account
- **Windows System**: WinRM with local user account and password authentication
- **Network Security**: All traffic controlled by pfSense firewall rules
- **VLAN Isolation**: Windows host properly isolated in Management VLAN

### Security Considerations
- **Password Storage**: Currently in group variables (can be encrypted with Ansible Vault)
- **Network Access**: Limited to Management VLAN with controlled firewall rules
- **User Privileges**: Windows ansible user has administrator rights for system management
- **Encryption**: WinRM configured for basic authentication over HTTP (can be upgraded to HTTPS)

## 🚀 Future Enhancement Opportunities

### Security Improvements
- **Certificate-based Authentication**: Replace basic auth with certificate authentication
- **Ansible Vault**: Encrypt Windows credentials in group variables
- **HTTPS Configuration**: Upgrade from HTTP to HTTPS for WinRM communication

### Automation Expansion
- **Windows-Specific Roles**: Develop Windows configuration management roles
- **Software Management**: Implement Chocolatey for Windows package management
- **Registry Management**: Automate Windows registry configuration
- **Service Management**: Comprehensive Windows service automation

### Additional Windows Systems
The framework now supports easy addition of more Windows systems:
1. Configure WinRM on new Windows host
2. Create ansible user account
3. Add firewall rule for WinRM
4. Add IP address to `[windows]` group in inventory
5. Test connectivity with `ansible windows -m win_ping`

## 🎯 Key Learnings

### Critical Success Factors
1. **Windows Firewall Configuration**: Essential for external WinRM access
2. **WinRM Authentication Setup**: Proper basic authentication configuration required
3. **Group Variables**: Clean approach for managing Windows-specific settings
4. **Cross-Platform Playbooks**: Necessary for mixed environment automation
5. **Systematic Troubleshooting**: Step-by-step approach to identify and resolve issues

### Best Practices Established
✅ **Document Each Step**: Critical for reproducing setup on additional systems  
✅ **Test Incrementally**: Verify each component before moving to next step  
✅ **Use Group Variables**: Cleaner than inline inventory configuration  
✅ **Platform-Specific Commands**: Use appropriate modules for each OS type  
✅ **Comprehensive Testing**: Validate both individual and combined operations  

## 📋 Implementation Checklist

### For Adding New Windows Hosts
- [ ] Configure PowerShell execution policy
- [ ] Enable and configure WinRM service
- [ ] Create ansible user account with administrator privileges
- [ ] Configure Windows Firewall rule for WinRM (port 5985)
- [ ] Test WinRM connectivity locally on Windows
- [ ] Add system to Ansible inventory
- [ ] Test connectivity with `ansible windows -m win_ping`
- [ ] Validate cross-platform automation

### Verification Commands
```bash
# Test Windows-only connectivity
ansible windows -m win_ping

# Test Linux-only connectivity  
ansible all_in_one -m ping

# Test cross-platform with conditional playbook
ansible-playbook playbooks/ping_all_systems.yml

# Test Windows-specific operations
ansible windows -m win_shell -a "Get-ComputerInfo | Select-Object WindowsProductName"
```

## ✅ Implementation Success

The Windows integration successfully demonstrates:

- **Enterprise Hybrid Environment**: Professional mixed-platform management
- **Scalable Architecture**: Framework supports additional Windows systems  
- **Unified Automation**: Single controller managing diverse infrastructure
- **Cross-Platform Workflows**: Conditional automation for different OS types
- **Security Separation**: Platform-appropriate authentication methods
- **Operational Excellence**: Clean configuration management practices

This implementation transforms the homelab from a Linux-only environment to a comprehensive enterprise-grade hybrid infrastructure, showcasing modern automation practices used in production environments.

---

*Windows Integration Status: ✅ Complete and Operational*  
*Platform Coverage: Linux (SSH) + Windows (WinRM) = Unified Enterprise Management*  
*Next Phase: Advanced Cross-Platform Automation Workflows*