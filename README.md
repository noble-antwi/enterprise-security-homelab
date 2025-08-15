# Enterprise-Grade Blue Team Security Lab

[![Documentation](https://img.shields.io/badge/docs-complete-brightgreen.svg)](docs/)
[![Lab Status](https://img.shields.io/badge/status-active-brightgreen.svg)]()
[![Automation](https://img.shields.io/badge/automation-enterprise--grade-blue.svg)]()
[![Cross-Platform](https://img.shields.io/badge/platform-linux+windows-purple.svg)]()
[![Ansible Roles](https://img.shields.io/badge/ansible-roles--based-purple.svg)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## 🏗️ Project Overview

A comprehensive, enterprise-grade cybersecurity homelab implementing professional security practices using **pfSense**, **VLAN segmentation**, **SIEM monitoring**, **cross-platform automation**, and **hybrid infrastructure management**. This lab environment showcases both monolithic and role-based automation approaches, demonstrating the evolution from basic playbooks to enterprise-grade automation practices across Linux and Windows platforms.

## 🏛️ Architecture Highlights

- **🔥 pfSense Firewall** - Enterprise routing & security
- **🌐 6 VLAN Segments** - Complete network isolation  
- **🔍 Wazuh SIEM** - Security monitoring & incident response
- **📊 Grafana/Prometheus** - Infrastructure observability
- **⚙️ Cross-Platform Automation** - Linux + Windows unified management
- **🧩 Modular Roles** - Enterprise-grade automation architecture
- **🔐 Service Account Management** - Professional automation practices
- **🖥️ Hybrid Infrastructure** - Mixed OS environment automation
- **🌍 Tailscale Mesh VPN** - Secure remote access

## 🗂️ Documentation Structure

| Module | Description | Status |
|--------|-------------|--------|
| **[01-network-infrastructure](docs/01-network-infrastructure.md)** | pfSense setup, VLAN architecture, switch configuration | ✅ Complete |
| **[02-security-monitoring](docs/02-security-monitoring.md)** | Wazuh SIEM deployment and BlueTeam VLAN setup | ✅ Complete |
| **[03-observability-stack](docs/03-observability-stack.md)** | Grafana & Prometheus monitoring deployment | ✅ Complete |
| **[04-automation-platform](docs/04-automation-platform.md)** | Ansible controller setup and configuration | ✅ Complete |
| **[05-remote-access](docs/05-remote-access.md)** | Tailscale mesh VPN implementation | ✅ Complete |
| **[06-ansible-service-account](docs/06-ansible-service-account.md)** | Enterprise automation service account setup | ✅ Complete |
| **[07-ansible-roles-architecture](docs/07-ansible-roles-architecture.md)** | Modular role-based automation framework | ✅ Complete |
| **[08-windows-integration](docs/08-windows-integration.md)** | **Windows host integration with Ansible** | **✅ Complete** |
| **[ssh-configuration](docs/ssh-configuration.md)** | SSH key management and friendly hostnames | ✅ Complete |
| **[troubleshooting](docs/troubleshooting.md)** | Common issues and solutions | ✅ Complete |

## 🏗️ Current Lab Infrastructure

### VLAN Architecture
| VLAN | Purpose | Subnet | Gateway | Services |
|------|---------|--------|---------|----------|
| **10 - Management** | Admin & Control | `192.168.10.0/24` | `.1` | pfSense GUI, Ansible Controller, **Windows Host** |
| **20 - BlueTeam** | Security Monitoring | `192.168.20.0/24` | `.1` | Wazuh SIEM All-in-One |
| **30 - RedTeam** | Attack Simulation | `192.168.30.0/24` | `.1` | *Reserved for Future* |
| **40 - DevOps** | CI/CD Pipeline | `192.168.40.0/24` | `.1` | *Reserved for Future* |
| **50 - EnterpriseLAN** | Business Services | `192.168.50.0/24` | `.1` | *Reserved for Future* |
| **60 - Monitoring** | Observability | `192.168.60.0/24` | `.1` | Grafana, Prometheus |

### Current Deployed Systems
| System | IP Address | VLAN | Purpose | OS | Status |
|--------|------------|------|---------|----| -------|
| **pfSense Firewall** | `192.168.10.1` | Management | Network gateway & security | FreeBSD | 🟢 Active |
| **Ansible Controller** | `192.168.10.2` | Management | Automation & configuration | Ubuntu 24.04 | 🟢 Active |
| **Windows Host** | **`192.168.10.3`** | **Management** | **Cross-platform automation** | **Windows 11 Pro** | **🟢 Active** |
| **TCM Ubuntu** | `192.168.10.4` | Management | Testing and development | Ubuntu 24.04 | 🟢 Active |
| **Wazuh SIEM** | `192.168.20.2` | BlueTeam | Security monitoring | Rocky Linux 9.6 | 🟢 Active |
| **Grafana Server** | `192.168.60.2` | Monitoring | Observability dashboard | Ubuntu 24.04 | 🟢 Active |

## 🚀 Getting Started

### Prerequisites
- Dedicated hardware for pfSense
- Managed switch with VLAN support
- Multiple systems for service deployment
- Windows system for cross-platform automation (optional)

### Recent Automation Enhancements ⚡
- **Cross-Platform Management**: Linux + Windows unified automation
- **Enterprise Role Architecture**: Modular, reusable automation components
- **Windows Integration**: WinRM-based Windows host management
- **Dual Implementation Strategy**: Both monolithic and role-based approaches
- **Professional Service Account**: Dedicated `ansible` user with passwordless automation
- **Hybrid Infrastructure**: Mixed OS environment with appropriate authentication
- **Advanced Template Usage**: Dynamic configuration generation with Jinja2
- **Comprehensive Testing**: Cross-platform verification and validation

### Quick Deployment
1. **Network Foundation** - Follow [01-network-infrastructure](docs/01-network-infrastructure.md)
2. **Security Monitoring** - Deploy using [02-security-monitoring](docs/02-security-monitoring.md)
3. **Observability** - Set up monitoring with [03-observability-stack](docs/03-observability-stack.md)
4. **Automation** - Configure Ansible from [04-automation-platform](docs/04-automation-platform.md)
5. **Service Account** - Implement enterprise automation via [06-ansible-service-account](docs/06-ansible-service-account.md)
6. **Role Architecture** - Deploy modular automation with [07-ansible-roles-architecture](docs/07-ansible-roles-architecture.md)
7. **Windows Integration** - Add Windows hosts via [08-windows-integration](docs/08-windows-integration.md)
8. **SSH Configuration** - Implement friendly hostnames via [ssh-configuration](docs/ssh-configuration.md)
9. **Remote Access** - Enable Tailscale via [05-remote-access](docs/05-remote-access.md)

## 🔧 Technology Stack

### Core Infrastructure
- **Firewall**: pfSense (FreeBSD-based)
- **Switch**: TP-Link TL-SG108E (Managed, VLAN-capable)
- **Virtualization**: VMware Workstation Pro

### Security & Monitoring
- **SIEM**: Wazuh 4.12.0 (All-in-One deployment)
- **Metrics**: Prometheus + Grafana
- **Log Management**: Integrated with Wazuh

### Automation & Management
- **Configuration Management**: Ansible with enterprise role architecture
- **Cross-Platform Support**: Linux (Ubuntu, Rocky) + Windows 11 Pro
- **Service Account**: Dedicated `ansible` user with passwordless sudo
- **Windows Management**: WinRM with local ansible user account
- **Remote Access**: Tailscale Mesh VPN
- **Operating Systems**: Ubuntu 24.04 LTS, Rocky Linux 9.6, Windows 11 Pro
- **SSH Management**: Custom key naming with friendly hostnames

## 🎯 Use Cases

### Blue Team Operations
- ✅ **Threat Detection** - Wazuh SIEM monitoring
- ✅ **Incident Response** - Centralized log analysis  
- ✅ **Infrastructure Monitoring** - Grafana dashboards
- ✅ **Secure Remote Access** - Tailscale mesh network

### DevOps & Automation
- ✅ **Cross-Platform Management** - Linux + Windows unified automation
- ✅ **Enterprise Role Architecture** - Modular, reusable automation components
- ✅ **Dual Implementation Strategy** - Both simple and advanced automation approaches
- ✅ **Hybrid Infrastructure Management** - Mixed OS environment automation
- ✅ **Professional Workflows** - Separation of personal and automated operations
- ✅ **Infrastructure as Code** - Version-controlled automation workflows
- ✅ **SSH Optimization** - Friendly hostnames and streamlined access

### Red Team Simulation *(Planned)*
- 🚧 **Attack Simulation** - Dedicated RedTeam VLAN
- 🚧 **Penetration Testing** - Isolated attack environment
- 🚧 **Tool Development** - Secure testing ground

### DevSecOps Integration *(Planned)*
- 🚧 **CI/CD Pipeline** - Automated security testing
- 🚧 **Infrastructure as Code** - Advanced Ansible automation
- 🚧 **Security Scanning** - Integrated vulnerability assessment

## 📊 Lab Metrics

### Implementation Status
- **Network Segmentation**: 6 VLANs configured
- **Security Monitoring**: Wazuh SIEM operational
- **Observability**: Grafana + Prometheus active
- **Automation**: Enterprise role architecture managing 6 systems
- **Cross-Platform Management**: 5 systems (4 Linux + 1 Windows)
- **Remote Access**: Tailscale mesh network deployed

### Security Posture
- **Network Isolation**: VLAN-based segmentation
- **Access Control**: pfSense firewall rules
- **Monitoring Coverage**: All VLANs monitored
- **Secure Remote Access**: WireGuard encryption
- **Automation Security**: Service account separation and audit trails

### Automation Capabilities
- **Cross-Platform Architecture**: Linux + Windows unified management
- **Role Architecture**: Modular, enterprise-grade automation components
- **Service Account**: Dedicated `ansible` user across all Linux systems
- **Windows Integration**: WinRM-based Windows host management
- **Passwordless Operations**: Zero-prompt automation workflows
- **Hybrid Environment**: Mixed OS automation with appropriate authentication
- **Professional Standards**: Enterprise-grade automation practices
- **Dual Implementation**: Both monolithic and role-based approaches available

## 🛠️ Cross-Platform Automation

### Hybrid Infrastructure Management
```
Total Managed Systems: 6 systems
├── Linux Infrastructure (SSH + ansible service account)
│   ├── 192.168.10.2 (Ansible Controller - Ubuntu)
│   ├── 192.168.10.4 (TCM Ubuntu)
│   ├── 192.168.20.2 (Wazuh SIEM - Rocky Linux)
│   └── 192.168.60.2 (Monitoring - Ubuntu)
└── Windows Infrastructure (WinRM + ansible user)
    └── 192.168.10.3 (Windows 11 Pro Host)
```

### Platform-Specific Management
| Platform | Systems | Connection | Authentication | Management Method |
|----------|---------|------------|----------------|-------------------|
| **Linux** | 4 systems | SSH | Service account (ansible) | Passwordless automation |
| **Windows** | 1 system | WinRM | Local user (ansible) | Password-based WinRM |

### Cross-Platform Automation Examples
```bash
# Platform-specific testing
ansible all_in_one -m ping     # Linux systems only
ansible windows -m win_ping    # Windows systems only

# Cross-platform automation (requires conditional playbooks)
ansible-playbook playbooks/ping_all_systems.yml

# Mixed environment management
ansible linux -m shell -a "uname -a"
ansible windows -m win_shell -a "Get-ComputerInfo"

# Service management across platforms
ansible linux -m systemd -a "name=ssh state=restarted"
ansible windows -m win_service -a "name=WinRM state=restarted"
```

### Available Automation Approaches

#### Role-Based Implementation (Recommended)
```bash
# Enterprise-grade modular automation
ansible-playbook ansible/playbooks/bootstrap-service-account-roles.yml --ask-become-pass
ansible-playbook ansible/playbooks/verify-service-account-roles.yml

# Individual role execution
ansible-playbook bootstrap-service-account-roles.yml --tags service_account
ansible-playbook bootstrap-service-account-roles.yml --skip-tags tools
```

#### Cross-Platform Playbooks
```bash
# Mixed environment automation
ansible-playbook playbooks/ping_all_systems.yml
ansible-playbook playbooks/system_info_cross_platform.yml
```

#### Monolithic Implementation (Educational)
```bash
# Traditional single-file approach
ansible-playbook ansible/playbooks/bootstrap-ansible-service-account.yml --ask-become-pass
ansible-playbook ansible/playbooks/verify-ansible-service-account.yml
```

### Windows-Specific Configuration
```yaml
# ansible/group_vars/windows.yml
---
ansible_connection: winrm
ansible_winrm_transport: basic
ansible_winrm_server_cert_validation: ignore
ansible_user: ansible
ansible_password: AnsiblePass123!
ansible_port: 5985
ansible_winrm_scheme: http
```

### Available Playbooks
| Playbook | Type | Platform | Purpose | Usage |
|----------|------|----------|---------|-------|
| **bootstrap-service-account-roles.yml** | Role-based | Linux | Enterprise service account creation | `ansible-playbook bootstrap-service-account-roles.yml --ask-become-pass` |
| **verify-service-account-roles.yml** | Role-based | Linux | Comprehensive role verification | `ansible-playbook verify-service-account-roles.yml` |
| **ping_all_systems.yml** | Cross-platform | All | Cross-platform connectivity testing | `ansible-playbook ping_all_systems.yml` |
| **bootstrap-ansible-service-account.yml** | Monolithic | Linux | Educational service account setup | `ansible-playbook bootstrap-ansible-service-account.yml --ask-become-pass` |
| **install_htop.yml** | Cross-platform | Linux | Cross-platform htop installation | `ansible-playbook install_htop.yml` |
| **install_apache.yml** | Utility | Linux | Cross-platform Apache installation | `ansible-playbook install_apache.yml` |

## 🛠️ Maintenance & Updates

### Regular Tasks
- Security updates across all systems via cross-platform automation
- Wazuh rule tuning and alert optimization
- Grafana dashboard refinement
- Ansible role development and maintenance
- Windows-specific configuration management
- Service account monitoring and security review

### Cross-Platform Monitoring
- All systems accessible via Tailscale and friendly hostnames
- Centralized logging through Wazuh
- Infrastructure metrics via Prometheus
- Visual dashboards in Grafana
- Automated health checks via Ansible roles
- Windows system monitoring via WinRM

## 🤝 Contributing

This project serves as a reference implementation for enterprise-grade homelabs with cross-platform automation. Feel free to:
- Fork and adapt for your environment
- Submit improvements via pull requests
- Share feedback and suggestions
- Contribute additional Ansible roles for Windows management

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **pfSense Community** - Excellent firewall platform
- **Wazuh Team** - Comprehensive SIEM solution
- **Tailscale** - Revolutionary mesh networking
- **Grafana Labs** - Outstanding observability tools
- **Ansible Community** - Powerful automation framework and cross-platform capabilities
- **Microsoft** - Windows Remote Management (WinRM) technology

---

*Last Updated: August 2025 | Status: Active Development with Cross-Platform Automation | Next Phase: Advanced Windows Management Workflows*