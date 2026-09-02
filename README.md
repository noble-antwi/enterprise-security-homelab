# Enterprise Information Security Lab

[![Documentation](https://img.shields.io/badge/docs-complete-brightgreen.svg)](docs/)
[![Lab Status](https://img.shields.io/badge/status-active-brightgreen.svg)]()
[![Platform Coverage](https://img.shields.io/badge/platforms-Linux%2BWindows%2BProxmox-blue.svg)]()
[![Automation](https://img.shields.io/badge/automation-Ansible-red.svg)]()

---

## Project Overview

A comprehensive, enterprise-grade cybersecurity homelab implementing professional security practices using **pfSense**, **VLAN segmentation**, **cross-platform automation**, **SIEM monitoring**, **remote access**, and **bare-metal virtualisation**. This lab environment mimics real-world infrastructure for Blue Team operations, Red Team simulation, and DevSecOps practices across Linux, Windows, and virtualised platforms.

---

## Architecture Highlights

- **pfSense Firewall** - Enterprise routing and security with 6-VLAN segmentation
- **Proxmox VE Hypervisor** - Bare-metal virtualisation with full multi-VLAN VM hosting
- **Cross-Platform Automation** - Ansible managing Linux, Windows, and Proxmox nodes
- **Wazuh SIEM** - Security monitoring and incident response across all platforms
- **Grafana/Prometheus** - Infrastructure observability and performance monitoring
- **Tailscale Mesh VPN** - Secure remote access to all lab resources globally
- **Windows Integration** - Professional Windows automation via WinRM and service accounts
- **Enterprise Security** - VLAN isolation, professional authentication, centralised monitoring

---

## Documentation Structure

| Module | Description | Status |
|--------|-------------|--------|
| **[01-network-infrastructure](docs/01-network-infrastructure.md)** | pfSense setup, VLAN architecture, switch configuration | Complete |
| **[02-security-monitoring](docs/02-security-monitoring.md)** | Wazuh SIEM deployment and BlueTeam VLAN setup | Complete |
| **[03-observability-stack](docs/03-observability-stack.md)** | Grafana and Prometheus monitoring deployment | Complete |
| **[04-automation-platform](docs/04-automation-platform.md)** | Cross-platform Ansible automation with Linux and Windows | Complete |
| **[05-remote-access](docs/05-remote-access.md)** | Tailscale mesh VPN implementation | Complete |
| **[06-ansible-service-account](docs/06-ansible-service-account.md)** | Ansible service account implementation for automation | Complete |
| **[07-ansible-roles-architecture](docs/07-ansible-roles-architecture.md)** | Role-based automation architecture | Complete |
| **[08-windows-integration](docs/08-windows-integration.md)** | Windows automation and integration implementation | Complete |
| **[09-bootstrap-procedures](docs/09-bootstrap-procedures.md)** | Ansible controller bootstrap and configuration | Complete |
| **[10-proxmox-hypervisor](docs/10-proxmox-hypervisor.md)** | Proxmox VE deployment, VLAN-aware bridge, trunk port migration | Complete |
| **[11-domain-controller-firewall](docs/11-domain-controller-firewall.md)** ([PDF](docs/11-domain-controller-firewall.pdf)) | pfSense aliases and rules for the DC01 domain controller: what each AD port does, how rules evaluate, target layout | In Progress |
| **[12-lab-expansion-roadmap](docs/12-lab-expansion-roadmap.md)** ([PDF](docs/12-lab-expansion-roadmap.pdf)) | Windows/AD estate growth plan: endpoint inventory, what each machine teaches, attack/defence scenarios, phased build, IAM repo decision | Planning |
| **[13-firewall-rulebase-governance](docs/13-firewall-rulebase-governance.md)** ([PDF](docs/13-firewall-rulebase-governance.pdf)) | Audit-grade rulebase governance: the 8 principles auditors check, a living rule register with per-rule justification and control mapping, change-control log, review cadence | In Progress |
| **[14-proxmox-storage-backup-capacity](docs/14-proxmox-storage-backup-capacity.md)** ([PDF](docs/14-proxmox-storage-backup-capacity.pdf)) | Proxmox storage layout, backup/recovery strategy (NIST CP-9), LXC-vs-VM capacity plan, and the lab-wide machine naming convention | Current |
| **[ssh-configuration](docs/ssh-configuration.md)** | SSH configuration and key management guide | Complete |
| **[troubleshooting](troubleshooting/)** | Comprehensive troubleshooting guides by component | Complete |

---

## Current Lab Infrastructure

### VLAN Architecture

| VLAN | Purpose | Subnet | Gateway | Services |
|------|---------|--------|---------|----------|
| **10 - Management** | Admin and Control | `192.168.10.0/24` | `.1` | pfSense, Ansible, Windows Systems, Proxmox |
| **20 - BlueTeam** | Security Monitoring | `192.168.20.0/24` | `.1` | Wazuh SIEM |
| **30 - RedTeam** | Attack Simulation | `192.168.30.0/24` | `.1` | Kali Linux (Proxmox VM) |
| **40 - DevOps** | CI/CD Pipeline | `192.168.40.0/24` | `.1` | HashiCorp Vault desktop (staged, awaiting configuration) |
| **50 - EnterpriseLAN** | Business Services | `192.168.50.0/24` | `.1` | Windows Server 2025 domain controller (`192.168.50.2`) |
| **60 - Monitoring** | Observability | `192.168.60.0/24` | `.1` | Grafana, Prometheus |

### Deployed Systems

| System | IP Address | VLAN | Platform | Purpose | Status |
|--------|------------|------|----------|---------|--------|
| pfSense Firewall | `192.168.10.1` | Management | FreeBSD | Network gateway and security | Active |
| Ansible Controller | `192.168.10.2` | Management | Ubuntu 24.04 | Cross-platform automation | Active (planned migration to Proxmox VM) |
| Laptop (Admin) | `192.168.10.3` | Management | Windows 11 | Administration workstation | Active |
| TCM Ubuntu | `192.168.10.4` | Management | Ubuntu 24.04 | Training and development | Active |
| Proxmox VE | `192.168.10.6` | Management | Proxmox VE | Bare-metal VM hypervisor | Active |
| Wazuh SIEM | `192.168.20.2` | BlueTeam | Rocky Linux 9.6 | Security monitoring | Active |
| Grafana Server | `192.168.60.2` | Monitoring | Ubuntu 24.04 | Observability dashboard | Active |
| Vault Desktop | `192.168.40.2` | DevOps | TBD | HashiCorp Vault secrets management | Staged (awaiting configuration) |
| DC01 (Windows Server 2025) | `192.168.50.2` | EnterpriseLAN | Windows Server 2025 | Domain controller for `ad.biira.online` (AD DS + DNS) | Active |

### Physical Network Layout

```
Internet
    |
pfSense (192.168.10.1)
    |
TP-Link TL-SG108E Managed Switch
    |
    |-- Port 1  Trunk (all VLANs)  pfSense ue0
    |-- Port 2  Trunk (all VLANs)  Switch 2 (secondary) -> Proxmox VE (192.168.10.6)
    |-- Port 3  VLAN 10 Access     Secondary unmanaged switch
    |               |
    |               |-- Laptop        (192.168.10.3)
    |-- Port 4  VLAN 20 Access     BlueTeam segment
    |-- Port 5  VLAN 30 Access     RedTeam segment
    |-- Port 6  VLAN 40 Access     Vault desktop (192.168.40.2, awaiting configuration)
    |-- Port 7  VLAN 50 Access     Windows Server 2025 DC (192.168.50.2)
    |-- Port 8  VLAN 60 Access     Monitoring segment
```

### Proxmox VM Hosting

Proxmox VE is connected to a trunk port carrying all VLANs, enabling VMs to be placed on any lab segment via a single VLAN-aware Linux bridge. A VM's network placement is determined solely by its VLAN Tag assignment at the virtual NIC level.

| VM | Bridge | VLAN Tag | Network | Purpose |
|----|--------|----------|---------|---------|
| Kali Linux | vmbr0 | 30 | 192.168.30.x | RedTeam attack simulation |
| Ansible Controller (planned) | vmbr0 | 10 | 192.168.10.2 (same IP) | Fresh rebuild of automation controller, replacing physical host (not yet configured) |
| Future BlueTeam VM | vmbr0 | 20 | 192.168.20.x | Security tooling |
| Future DevOps VM | vmbr0 | 40 | 192.168.40.x | CI/CD pipelines |

---

## Lab Capabilities

### Operational Capabilities

- **Virtualisation**: Proxmox VE node with multi-VLAN VM hosting across all lab segments
- **Cross-Platform Automation**: Ansible managing 6 systems across Linux, Windows, and Proxmox
- **Security Monitoring**: Wazuh SIEM with centralised logging across all platforms
- **Performance Monitoring**: Real-time infrastructure health via Grafana and Prometheus
- **Remote Operations**: Global access to all lab resources via Tailscale mesh VPN
- **Scalability**: Proxmox enables rapid deployment of new VMs on any VLAN without physical changes

### Security Posture

- **Network Isolation**: VLAN-based segmentation with pfSense firewall enforcement
- **Access Control**: Role-based access with platform-appropriate authentication methods
- **Monitoring Coverage**: All VLANs and systems monitored by centralised SIEM
- **Secure Remote Access**: WireGuard encryption via Tailscale mesh networking
- **Professional Standards**: Enterprise-grade authentication, service accounts, and audit trails
- **Incident Response**: Centralised logging and alerting across all infrastructure components

### Platform Coverage Metrics

| Platform | Systems | Authentication | Management | Status |
|----------|---------|---------------|------------|--------|
| Linux | 4 systems | SSH Keys (ED25519) | Ansible + SSH | 100% Managed |
| Windows | 2 systems (Windows 11 + Server 2025 DC) | WinRM + Service Accounts | Ansible + WinRM | DC Ansible onboarding pending |
| Proxmox VE | 1 node | SSH + Web UI (port 8006) | Ansible + SSH | Active |
| Network | pfSense + Switch | Web UI + SSH | Manual + Automation | Fully Operational |
| Total | 8 active + 1 staged | Multi-method | Cross-platform | Enterprise-Ready |

---

## Development Roadmap

### Phase 1: Foundation — Complete

- Network infrastructure with 6-VLAN segmentation
- Security monitoring with Wazuh SIEM
- Cross-platform automation with Ansible
- Remote access via Tailscale mesh VPN
- Observability stack with Grafana and Prometheus

### Phase 2: Virtualisation and Advanced Security — In Progress

- Proxmox VE hypervisor deployed with VLAN-aware trunk port configuration
- RedTeam VLAN (30) accessible from Proxmox for isolated VM deployment
- Kali Linux VM deployment on VLAN 30 in progress
- Ansible controller migration from physical host to Proxmox VM (planned, not yet configured)
- Wazuh agent deployment across all platforms
- Custom detection rules and automated response workflows
- Advanced Grafana dashboards for security metrics

### Phase 3: Red Team Capabilities — Planned

- Kali Linux fully operational on VLAN 30
- Attack simulation and penetration testing environment
- Purple team exercise frameworks
- Security tool development and testing environment

### Phase 4: DevSecOps Integration — Future

- CI/CD pipeline integration with security scanning
- Infrastructure as Code enhancement
- Automated compliance checking and reporting
- Advanced automation workflows and orchestration

---

## Monitoring and Health Checks

- **All Systems**: Accessible and manageable via Tailscale mesh network
- **Centralised Logging**: Comprehensive log collection through Wazuh SIEM
- **Infrastructure Metrics**: Real-time performance monitoring via Prometheus
- **Visual Dashboards**: System health and security status via Grafana
- **Cross-Platform Status**: Unified monitoring via Ansible automation platform
- **Network Health**: pfSense monitoring and VLAN performance tracking

---

## Maintenance and Operations

### Regular Maintenance Tasks

- **Security Updates**: Automated and manual patching across Linux and Windows systems
- **Wazuh Rule Tuning**: Continuous optimisation of detection rules and alert thresholds
- **Grafana Dashboard Enhancement**: Regular improvement of monitoring visualisations
- **Ansible Playbook Development**: Ongoing automation enhancement and capability additions
- **System Performance Optimisation**: Regular review and tuning of infrastructure performance
- **Documentation Updates**: Continuous improvement of procedures and troubleshooting guides
- **Proxmox Maintenance**: Periodic host and VM updates via web UI and CLI

---

## Contributing

This project serves as a comprehensive reference implementation for enterprise-grade security homelabs.

Community involvement is welcomed:

- **Fork and Adapt**: Use as foundation for your own security lab environment
- **Submit Improvements**: Pull requests for documentation, procedures, and automation enhancements
- **Share Experiences**: Issue discussions for troubleshooting and best practices
- **Knowledge Sharing**: Contribute lessons learned and advanced configurations

### Contribution Guidelines

- Maintain focus on enterprise-grade practices and professional standards
- Include comprehensive documentation for any new features or procedures
- Test thoroughly across all platforms where applicable
- Follow existing documentation structure and formatting standards

---

## Acknowledgments

- **pfSense Community** - Outstanding firewall platform with comprehensive VLAN and routing capabilities
- **Proxmox Team** - Excellent bare-metal hypervisor with powerful VLAN-aware networking
- **Wazuh Team** - Exceptional SIEM solution with powerful threat detection and analysis features
- **Tailscale** - Revolutionary mesh networking solution that transformed remote access capabilities
- **Grafana Labs** - Excellent observability platform with powerful visualisation and monitoring tools
- **Ansible Community** - Robust automation platform with outstanding cross-platform support

---

## Quick Status Overview

The enterprise homelab demonstrates professional security practices, comprehensive cross-platform automation, advanced monitoring capabilities, and bare-metal virtualisation in a scalable, well-documented infrastructure. The implementation showcases real-world enterprise security operations, making it suitable for Blue Team training, security research, professional development, and demonstrating advanced cybersecurity capabilities.

**Current Achievement**: Proxmox VE hypervisor integrated on a full VLAN trunk port, enabling VM deployment across all six lab segments from a single physical node — combined with unified Ansible management, enterprise-grade authentication, comprehensive SIEM monitoring, and secure global remote access via Tailscale.
