# Enterprise-Grade Blue Team Security Lab

[![Documentation](https://img.shields.io/badge/docs-complete-brightgreen.svg)](docs/)
[![Lab Status](https://img.shields.io/badge/status-active-brightgreen.svg)]()
[![Platform Coverage](https://img.shields.io/badge/platforms-Linux%2BWindows-blue.svg)]()
[![Automation](https://img.shields.io/badge/automation-Ansible-red.svg)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

##  Project Overview

A comprehensive, enterprise-grade cybersecurity homelab implementing professional security practices using **pfSense**, **VLAN segmentation**, **cross-platform automation**, **SIEM monitoring**, and **remote access**. This lab environment mimics real-world infrastructure for Blue Team operations, Red Team simulation, and DevSecOps practices across both Linux and Windows platforms.

##  Architecture Highlights

- **pfSense Firewall** - Enterprise routing & security with 6-VLAN segmentation
- **Cross-Platform Automation** - Ansible managing Linux and Windows systems seamlessly
- **Wazuh SIEM** - Security monitoring & incident response across all platforms
- **Grafana/Prometheus** - Infrastructure observability and performance monitoring
- **Tailscale Mesh VPN** - Secure remote access to all lab resources globally
- **Windows Integration** - Professional Windows automation via WinRM and service accounts
- **Enterprise Security** - VLAN isolation, professional authentication, centralized monitoring

   ## Documentation Structure

| Module | Description | Status |
|--------|-------------|--------|
| **[01-network-infrastructure](docs/01-network-infrastructure.md)** | pfSense setup, VLAN architecture, switch configuration | Complete |
| **[02-security-monitoring](docs/02-security-monitoring.md)** | Wazuh SIEM deployment and BlueTeam VLAN setup | Complete |
| **[03-observability-stack](docs/03-observability-stack.md)** | Grafana & Prometheus monitoring deployment | Complete |
| **[04-automation-platform](docs/04-automation-platform.md)** | Cross-platform Ansible automation with Linux & Windows | Complete |
| **[05-remote-access](docs/05-remote-access.md)** | Tailscale mesh VPN implementation | Complete |
| **[06-ansible-service-account](docs/06-ansible-service-account.md)** | Ansible service account implementation for automation | Complete |
| **[07-ansible-roles-architecture](docs/07-ansible-roles-architecture.md)** | Role-based automation architecture | Complete |
| **[08-windows-integration](docs/08-windows-integration.md)** | Windows automation & integration implementation | Complete |
Standardized bootstrap procedures for new systems | Complete |
| **[ssh-configuration](docs/ssh-configuration.md)** | SSH configuration and key management guide | Complete |
| **[troubleshooting](troubleshooting/)** | Comprehensive troubleshooting guides by component | Complete |


##  Current Lab Infrastructure

### VLAN Architecture
| VLAN | Purpose | Subnet | Gateway | Services |
|------|---------|--------|---------|----------|
| **10 - Management** | Admin & Control | `192.168.10.0/24` | `.1` | pfSense GUI, Ansible Controller, Windows Systems |
| **20 - BlueTeam** | Security Monitoring | `192.168.20.0/24` | `.1` | Wazuh SIEM All-in-One |
| **30 - RedTeam** | Attack Simulation | `192.168.30.0/24` | `.1` | *Reserved for Future* |
| **40 - DevOps** | CI/CD Pipeline | `192.168.40.0/24` | `.1` | *Reserved for Future* |
| **50 - EnterpriseLAN** | Business Services | `192.168.50.0/24` | `.1` | *Reserved for Future* |
| **60 - Monitoring** | Observability | `192.168.60.0/24` | `.1` | Grafana, Prometheus |

![VLAN Structure](<images/11. vlans structure.png>)
VLAN struture Implementation with WAN Interface.

### Current Deployed Systems
| System | IP Address | VLAN | Platform | Purpose | Status |
|--------|------------|------|----------|---------|--------|
| **pfSense Firewall** | `192.168.10.1` | Management | FreeBSD | Network gateway & security |  Active |
| **Ansible Controller** | `192.168.10.2` | Management | Ubuntu 24.04 | Cross-platform automation |  Active |
| **Windows Host Laptop** | `192.168.10.3` | Management | Windows 10/11 | Development/Testing |  Active |
| **TCM Ubuntu** | `192.168.10.4` | Management | Ubuntu 24.04 | Training/Development |  Active |
| **Windows Server 2022** | `192.168.10.5` | Management | Windows Server | Enterprise Services |  Active |
| **Wazuh SIEM** | `192.168.20.2` | BlueTeam | Rocky Linux 9.6 | Security monitoring |  Active |
| **Grafana Server** | `192.168.60.2` | Monitoring | Ubuntu 24.04 | Observability dashboard |  Active |

### Infrastructure Overview
- **Total Systems**: 7 managed systems across 3 active VLANs
- **Platform Coverage**: Linux (4 systems) + Windows (2 systems) + pfSense
- **Automation Scope**: Cross-platform Ansible management (6 systems)
- **Remote Access**: Tailscale mesh VPN (global connectivity)
- **Security Monitoring**: Wazuh SIEM operational across all platforms
- **Observability**: Grafana/Prometheus stack with comprehensive metrics

##  Getting Started

### Prerequisites
- Dedicated hardware for pfSense firewall
- Managed switch with VLAN support (TP-Link TL-SG108E or equivalent)
- Multiple systems for service deployment
- Basic networking and virtualization knowledge
- Understanding of both Linux and Windows administration


### Bootstrap New Systems
For adding new systems to the infrastructure:

#### Linux Systems
```bash
# Distribute SSH keys and add to inventory
ssh-copy-id -i ~/.ssh/ansible-homelab-key.pub user@[IP_ADDRESS]
echo "[IP_ADDRESS]   # [DESCRIPTION] - $(date)" >> /etc/ansible/hosts
ansible [IP_ADDRESS] -m ping
```
**Bootstrap Methods:**
- **Service Account Setup**: See [06-ansible-service-account.md](docs/06-ansible-service-account.md)
- **Role-Based Bootstrap**: See [07-ansible-roles-architecture.md](docs/07-ansible-roles-architecture.md)

#### Windows Systems
```bash
# Run automated bootstrap process
ansible-playbook bootstrap_windows.yml \
    -e "target_host=[IP_ADDRESS]" \
    -e "initial_user=Administrator" \
    -e "initial_password=[ADMIN_PASSWORD]" \
    -e "ansible_service_password=Password123"
```
**Windows Integration Guide**: See [08-windows-integration.md](docs/08-windows-integration.md)

### Quick Validation Commands
```bash
# Verify all systems status
ansible all_in_one -m ping        # Linux systems
ansible windows -m win_ping        # Windows systems

# Check service health across platforms
ansible linux_systems -m systemd -a "name=ssh state=started"
ansible windows -m win_service -a "name=WinRM"

# Access web interfaces via Tailscale
# pfSense: https://192.168.10.1
# Wazuh: https://192.168.20.2
# Grafana: http://192.168.60.2:3000
```

## 🔧 Technology Stack

### Core Infrastructure
- **Firewall**: pfSense (FreeBSD-based) with advanced VLAN routing
- **Switch**: TP-Link TL-SG108E (Managed, VLAN-capable, 8-port Gigabit)
- **Virtualization**: VMware Workstation Pro for lab controller
- **Network Architecture**: VLAN segmentation with controlled inter-VLAN routing

### Security & Monitoring
- **SIEM**: Wazuh 4.12.0 (All-in-One deployment on Rocky Linux 9.6)
- **Metrics Collection**: Prometheus with comprehensive system monitoring
- **Visualization**: Grafana dashboards for infrastructure observability
- **Log Management**: Centralized through Wazuh with real-time analysis
- **Network Security**: pfSense firewall rules with default-deny policies

### Automation & Management
- **Configuration Management**: Ansible with cross-platform capabilities
- **Remote Access**: Tailscale Mesh VPN with WireGuard encryption
- **Operating Systems**: Ubuntu 24.04 LTS, Rocky Linux 9.6, Windows 10/11/Server 2022
- **Version Control**: Git-based infrastructure documentation and procedures

### Authentication Architecture
- **Linux Systems**: SSH key-based authentication (ED25519 cryptography)
- **Windows Systems**: WinRM with dedicated service accounts and Administrator privileges
- **Network Access**: Tailscale mesh networking with automatic WireGuard encryption
- **Service Accounts**: Professional separation between personal and automation access
- **Remote Management**: Secure global access via Tailscale to all lab resources

## Use Cases & Capabilities

### Blue Team Operations
- **Comprehensive Threat Detection** - Wazuh SIEM monitoring across all platforms
- **Cross-Platform Incident Response** - Centralized log analysis from Linux and Windows
- **Infrastructure Health Monitoring** - Grafana dashboards for system performance
- **Secure Global Access** - Tailscale mesh network for remote operations
- **Automated Configuration Management** - Consistent security posture via Ansible
- **Professional Authentication** - Enterprise-grade access controls and service accounts

### Cross-Platform Management
-  **Unified Automation** - Single Ansible controller managing Linux and Windows systems
-  **Consistent Configuration** - Standardized management processes across platforms
-  **Professional Authentication** - Platform-appropriate security standards implemented
-  **Scalable Architecture** - Easy addition of new systems via automated bootstrap procedures
-  **Operational Efficiency** - Reduced manual configuration through systematic automation
- **Enterprise Standards** - Professional service account management and variable architecture

### Red Team Simulation *(Planned Expansion)*
- **Controlled Attack Simulation** - Dedicated RedTeam VLAN for isolated testing
- **Penetration Testing Environment** - Safe space for security tool development
- **Purple Team Exercises** - Coordinated Red/Blue team training scenarios

### DevSecOps Integration *(Future Development)*
- **CI/CD Security Pipeline** - Automated security testing in deployment workflows
- **Infrastructure as Code** - Ansible automation with version-controlled configurations
- **Integrated Vulnerability Assessment** - Automated scanning and remediation workflows
- **Compliance Automation** - Regulatory compliance monitoring and reporting

### Security Research & Development
- **Multi-Platform Testing** - Security tools and configurations across Linux/Windows
- **Network Segmentation Testing** - VLAN isolation and firewall rule validation
- **Monitoring System Development** - Custom dashboards and alerting mechanisms
- **Automation Development** - Cross-platform configuration management playbooks

## Lab Metrics & Status

### Implementation Status
- **Network Segmentation**: 6 VLANs configured with 3 actively utilized
- **Security Monitoring**: Wazuh SIEM collecting and analyzing logs from all systems
- **Cross-Platform Automation**: Ansible managing 6 systems across 2 platforms  
- **Observability**: Grafana + Prometheus monitoring infrastructure health
- **Remote Access**: Tailscale mesh network providing secure global connectivity
- **Bootstrap Automation**: Standardized procedures for rapid system integration
- **Documentation**: Comprehensive procedures covering all operational aspects

### Security Posture
- **Network Isolation**: VLAN-based segmentation with pfSense firewall control
- **Access Control**: Role-based access with platform-appropriate authentication methods
- **Monitoring Coverage**: All VLANs and systems monitored by centralized SIEM
- **Secure Remote Access**: WireGuard encryption via Tailscale mesh networking
- **Professional Standards**: Enterprise-grade authentication, service accounts, and audit trails
- **Incident Response**: Centralized logging and alerting across all infrastructure components

### Operational Capabilities
- **System Management**: Cross-platform automation for configuration and deployment
- **Performance Monitoring**: Real-time infrastructure health and performance metrics
- **Security Monitoring**: Continuous threat detection and security event analysis
- **Remote Operations**: Global access to all lab resources via encrypted mesh VPN
- **Scalability**: Proven procedures for rapid integration of additional systems
- **Knowledge Management**: Complete documentation of procedures and troubleshooting

### Platform Coverage Metrics
| Platform | Systems | Authentication | Management | Status |
|----------|---------|---------------|------------|--------|
| **Linux** | 4 systems | SSH Keys (ED25519) | Ansible + SSH |  100% Managed |
| **Windows** | 2 systems | WinRM + Service Accounts | Ansible + WinRM |  100% Managed |
| **Network** | pfSense + Switch | Web UI + SSH | Manual + Automation |  Fully Operational |
| **Total** | 7 systems | Multi-method | Cross-platform |  Enterprise-Ready |

##  Maintenance & Operations

### Regular Maintenance Tasks
- **Security Updates**: Automated and manual patching across Linux and Windows systems
- **Wazuh Rule Tuning**: Continuous optimization of detection rules and alert thresholds
- **Grafana Dashboard Enhancement**: Regular improvement of monitoring visualizations
- **Ansible Playbook Development**: Ongoing automation enhancement and new capability addition
- **System Performance Optimization**: Regular review and tuning of infrastructure performance
- **Documentation Updates**: Continuous improvement of procedures and troubleshooting guides

### Monitoring & Health Checks
- **All Systems**: Accessible and manageable via Tailscale mesh network
- **Centralized Logging**: Comprehensive log collection through Wazuh SIEM
- **Infrastructure Metrics**: Real-time performance monitoring via Prometheus
- **Visual Dashboards**: System health and security status via Grafana
- **Cross-Platform Status**: Unified monitoring via Ansible automation platform
- **Network Health**: pfSense monitoring and VLAN performance tracking

### Expansion & Scalability
- **Windows Systems**: Ready for additional Windows servers via automated bootstrap procedures
- **Linux Integration**: Streamlined process for new Linux system integration via SSH key distribution  
- **Network Capacity**: Infrastructure supports additional VLANs and network segments
- **Service Deployment**: Automation framework enables rapid deployment of new services
- **Geographic Distribution**: Tailscale mesh supports global lab expansion
- **Platform Diversity**: Architecture supports additional operating systems and platforms

## Development Roadmap

### Phase 1: Foundation  Complete
- Network infrastructure with VLAN segmentation
-  Security monitoring with Wazuh SIEM
-  Cross-platform automation with Ansible
-  Remote access via Tailscale mesh VPN
-  Observability stack with Grafana/Prometheus

### Phase 2: Advanced Security  In Progress
-  Wazuh agent deployment across all platforms
-  Custom detection rules and automated response
-  Advanced Grafana dashboards for security metrics
-  Integration of security tools across platforms

### Phase 3: Red Team Capabilities Planned
-  RedTeam VLAN activation and tool deployment
-  Attack simulation and penetration testing environment
-  Purple team exercise frameworks
-  Security tool development and testing

### Phase 4: DevSecOps Integration  Future
-  CI/CD pipeline integration with security scanning
-  Infrastructure as Code enhancement
-  Automated compliance checking and reporting
-  Advanced automation workflows and orchestration

##  Contributing

This project serves as a comprehensive reference implementation for enterprise-grade security homelabs. Community involvement is welcomed:

- **Fork and Adapt**: Use as foundation for your own security lab environment
- **Submit Improvements**: Pull requests for documentation, procedures, and automation enhancements
- **Share Experiences**: Issue discussions for troubleshooting and best practices
- **Knowledge Sharing**: Contribute lessons learned and advanced configurations

### Contribution Guidelines
- Maintain focus on enterprise-grade practices and professional standards
- Include comprehensive documentation for any new features or procedures
- Test thoroughly across both Linux and Windows platforms where applicable
- Follow existing documentation structure and formatting standards

##  Acknowledgments

- **pfSense Community** - Outstanding firewall platform with comprehensive VLAN and routing capabilities
- **Wazuh Team** - Exceptional SIEM solution with powerful threat detection and analysis features
- **Tailscale** - Revolutionary mesh networking solution that transformed remote access capabilities
- **Grafana Labs** - Excellent observability platform with powerful visualization and monitoring tools
- **Ansible Community** - Robust automation platform with outstanding cross-platform support

## Quick Status Overview

The enterprise homelab demonstrates professional security practices, comprehensive cross-platform automation, and advanced monitoring capabilities in a scalable, well-documented infrastructure. The implementation showcases real-world enterprise security operations, making it suitable for Blue Team training, security research, professional development, and demonstrating advanced cybersecurity capabilities.

**Key Achievement**: Successful integration of Linux and Windows systems under unified Ansible management with enterprise-grade authentication, comprehensive monitoring, and secure global remote access - providing a complete foundation for advanced cybersecurity operations and continuous learning.