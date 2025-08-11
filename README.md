# Enterprise-Grade Blue Team Security Lab

[![Documentation](https://img.shields.io/badge/docs-complete-brightgreen.svg)](docs/)
[![Lab Status](https://img.shields.io/badge/status-active-brightgreen.svg)]()
[![Automation](https://img.shields.io/badge/automation-enterprise--grade-blue.svg)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## 🏗️ Project Overview

A comprehensive, enterprise-grade cybersecurity homelab implementing professional security practices using **pfSense**, **VLAN segmentation**, **SIEM monitoring**, **automation**, and **service account management**. This lab environment mimics real-world infrastructure for Blue Team operations, Red Team simulation, and DevSecOps practices with professional automation workflows.

## 🏛️ Architecture Highlights

- **🔥 pfSense Firewall** - Enterprise routing & security
- **🌐 6 VLAN Segments** - Complete network isolation  
- **🔍 Wazuh SIEM** - Security monitoring & incident response
- **📊 Grafana/Prometheus** - Infrastructure observability
- **⚙️ Ansible Automation** - Enterprise service account configuration
- **🔐 Service Account Management** - Professional automation practices
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
| **[ssh-configuration](docs/ssh-configuration.md)** | SSH key management and friendly hostnames | ✅ Complete |
| **[troubleshooting](docs/troubleshooting.md)** | Common issues and solutions | ✅ Complete |

## 🏗️ Current Lab Infrastructure

### VLAN Architecture
| VLAN | Purpose | Subnet | Gateway | Services |
|------|---------|--------|---------|----------|
| **10 - Management** | Admin & Control | `192.168.10.0/24` | `.1` | pfSense GUI, Ansible Controller |
| **20 - BlueTeam** | Security Monitoring | `192.168.20.0/24` | `.1` | Wazuh SIEM All-in-One |
| **30 - RedTeam** | Attack Simulation | `192.168.30.0/24` | `.1` | *Reserved for Future* |
| **40 - DevOps** | CI/CD Pipeline | `192.168.40.0/24` | `.1` | *Reserved for Future* |
| **50 - EnterpriseLAN** | Business Services | `192.168.50.0/24` | `.1` | *Reserved for Future* |
| **60 - Monitoring** | Observability | `192.168.60.0/24` | `.1` | Grafana, Prometheus |

### Current Deployed Systems
| System | IP Address | VLAN | Purpose | Status |
|--------|------------|------|---------|--------|
| **pfSense Firewall** | `192.168.10.1` | Management | Network gateway & security | 🟢 Active |
| **Ansible Controller** | `192.168.10.2` | Management | Automation & configuration | 🟢 Active |
| **Wazuh SIEM** | `192.168.20.2` | BlueTeam | Security monitoring | 🟢 Active |
| **Grafana Server** | `192.168.60.2` | Monitoring | Observability dashboard | 🟢 Active |

## 🚀 Getting Started

### Prerequisites
- Dedicated hardware for pfSense
- Managed switch with VLAN support
- Multiple systems for service deployment

### Recent Automation Enhancements ⚡
- **Enterprise Service Account**: Dedicated `ansible` user for professional automation
- **Passwordless Automation**: No sudo password prompts during automation workflows
- **Cross-Platform Support**: Unified automation across Ubuntu and Rocky Linux
- **Enhanced Security**: Clear separation between personal and automated operations
- **Professional Workflow**: Enterprise-grade infrastructure management practices

### Quick Deployment
1. **Network Foundation** - Follow [01-network-infrastructure](docs/01-network-infrastructure.md)
2. **Security Monitoring** - Deploy using [02-security-monitoring](docs/02-security-monitoring.md)
3. **Observability** - Set up monitoring with [03-observability-stack](docs/03-observability-stack.md)
4. **Automation** - Configure Ansible from [04-automation-platform](docs/04-automation-platform.md)
5. **Service Account** - Implement enterprise automation via [06-ansible-service-account](docs/06-ansible-service-account.md)
6. **SSH Configuration** - Implement friendly hostnames via [ssh-configuration](docs/ssh-configuration.md)
7. **Remote Access** - Enable Tailscale via [05-remote-access](docs/05-remote-access.md)

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
- **Configuration Management**: Ansible with enterprise service account
- **Service Account**: Dedicated `ansible` user with passwordless sudo
- **Remote Access**: Tailscale Mesh VPN
- **Operating Systems**: Ubuntu 24.04 LTS, Rocky Linux 9.6
- **SSH Management**: Custom key naming with friendly hostnames

## 🎯 Use Cases

### Blue Team Operations
- ✅ **Threat Detection** - Wazuh SIEM monitoring
- ✅ **Incident Response** - Centralized log analysis  
- ✅ **Infrastructure Monitoring** - Grafana dashboards
- ✅ **Secure Remote Access** - Tailscale mesh network

### DevOps & Automation
- ✅ **Enterprise Automation** - Service account with passwordless privilege escalation
- ✅ **Cross-Platform Management** - Ubuntu and Rocky Linux unified automation
- ✅ **Professional Workflows** - Separation of personal and automated operations
- ✅ **Configuration Management** - Infrastructure as code practices
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
- **Automation**: Enterprise service account managing 4 systems
- **Remote Access**: Tailscale mesh network deployed

### Security Posture
- **Network Isolation**: VLAN-based segmentation
- **Access Control**: pfSense firewall rules
- **Monitoring Coverage**: All VLANs monitored
- **Secure Remote Access**: WireGuard encryption
- **Automation Security**: Service account separation and audit trails

### Automation Capabilities
- **Service Account**: Dedicated `ansible` user across all systems
- **Passwordless Operations**: Zero-prompt automation workflows
- **Cross-Platform Support**: Ubuntu and Rocky Linux unified management
- **Professional Standards**: Enterprise-grade automation practices
- **Scalable Foundation**: Ready for complex orchestration workflows

## 🛠️ Ansible Automation

### Service Account Structure
| Account | Purpose | Access Level | Sudo Requirements |
|---------|---------|--------------|-------------------|
| **nantwi** | Personal admin, development | Full administrative | Password required |
| **ansible** | Automation service | Automation tasks only | Passwordless (NOPASSWD) |

### Quick Automation Commands
```bash
# Basic connectivity test
ansible all_in_one -m ping

# System information gathering
ansible all_in_one -m shell -a "uptime"

# Service management
ansible wazuh-server -m systemd -a "name=wazuh-manager state=restarted"
ansible monitoring-server -m systemd -a "name=grafana-server state=restarted"

# Cross-platform package management
ansible all_in_one -m package -a "name=curl state=present"
```

### Available Playbooks
| Playbook | Purpose | Usage |
|----------|---------|-------|
| **bootstrap-ansible-service-account.yml** | Create automation service account | `ansible-playbook bootstrap-ansible-service-account.yml --ask-become-pass` |
| **verify-ansible-service-account.yml** | Verify service account setup | `ansible-playbook verify-ansible-service-account.yml` |
| **install_htop.yml** | Cross-platform htop installation | `ansible-playbook install_htop.yml` |
| **install_apache.yml** | Cross-platform Apache installation | `ansible-playbook install_apache.yml` |
| **remove_apache.yml** | Cross-platform Apache removal | `ansible-playbook remove_apache.yml` |

## 🛠️ Maintenance & Updates

### Regular Tasks
- Security updates across all systems via automation
- Wazuh rule tuning and alert optimization
- Grafana dashboard refinement
- Ansible playbook maintenance and development
- Service account monitoring and maintenance

### Monitoring
- All systems accessible via Tailscale and friendly hostnames
- Centralized logging through Wazuh
- Infrastructure metrics via Prometheus
- Visual dashboards in Grafana
- Automated health checks via Ansible

## 🤝 Contributing

This project serves as a reference implementation for enterprise-grade homelabs. Feel free to:
- Fork and adapt for your environment
- Submit improvements via pull requests
- Share feedback and suggestions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **pfSense Community** - Excellent firewall platform
- **Wazuh Team** - Comprehensive SIEM solution
- **Tailscale** - Revolutionary mesh networking
- **Grafana Labs** - Outstanding observability tools
- **Ansible Community** - Powerful automation framework

---

*Last Updated: August 2025 | Status: Active Development with Enterprise Service Account | Next Phase: Advanced Automation Workflows*