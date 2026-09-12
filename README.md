<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/brand/biira-bank-lockup-reverse-960.png">
  <img src="images/brand/biira-bank-lockup-960.png" alt="Biira Bank" width="380">
</picture>

# Enterprise Information Security Lab

**The scenario.** This environment is built and documented as the infrastructure of a fictional regional bank, **Biira Bank**. The domain is real (`corp.biirabank.com`), the segmentation is real, and the controls are tested rather than described. Working to a named organisation rather than an abstract "lab" forces the decisions a real environment forces: who needs to reach what, why a rule exists, what an auditor would ask, and what happens when something fails. Financial services was chosen deliberately, because it is the sector where segmentation, least privilege, change control and evidence are least optional.

The sibling repository [enterprise-iam-lab](https://github.com/noble-antwi/enterprise-iam-lab) documents the same organisation's identity estate (Active Directory, Okta, Entra) and is built on the architecture described here. Both repositories share one visual identity, documented in [images/brand](images/brand/README.md): a vault door inside a shield, where the shield is the protected boundary and the vault door is the controlled way through it. That reads as network segmentation here and as authentication and authorisation there.

**Elsewhere:** project write-ups and other work at [noble-antwi.github.io](https://noble-antwi.github.io/). Selected procedures are recorded on video and linked from the document they belong to, for example [deploying the first Wazuh agent](https://youtu.be/Tsh_W0gWIRc) (`docs/16`).

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
- **Active Directory** - `corp.biirabank.com` on a physical domain controller, with a tiered OU and group structure
- **Wazuh SIEM** - Agent-based monitoring and CIS configuration assessment on SIEM01
- **Greenbone** - Network vulnerability scanning from a Tier 0 VM, with a least-privilege scan identity
- **Tailscale Mesh VPN** - Remote access to lab resources
- **Ansible and Grafana/Prometheus** - Previously deployed (`docs/03`, `docs/04`), both awaiting rebuild as Proxmox guests

---

## Documentation Structure

| Module | Description | Status |
|--------|-------------|--------|
| **[01-network-infrastructure](docs/01-network-infrastructure.md)** ([PDF](docs/01-network-infrastructure.pdf)) | pfSense setup, VLAN architecture, switch configuration | Complete |
| **[02-security-monitoring](docs/02-security-monitoring.md)** ([PDF](docs/02-security-monitoring.pdf)) | Wazuh SIEM deployment and BlueTeam VLAN setup | Complete |
| **[03-observability-stack](docs/03-observability-stack.md)** ([PDF](docs/03-observability-stack.pdf)) | Grafana and Prometheus monitoring deployment | Complete |
| **[04-automation-platform](docs/04-automation-platform.md)** ([PDF](docs/04-automation-platform.pdf)) | Cross-platform Ansible automation with Linux and Windows | Complete |
| **[05-remote-access](docs/05-remote-access.md)** ([PDF](docs/05-remote-access.pdf)) | Tailscale mesh VPN implementation | Complete |
| **[06-ansible-service-account](docs/06-ansible-service-account.md)** ([PDF](docs/06-ansible-service-account.pdf)) | Ansible service account implementation for automation | Complete |
| **[07-ansible-roles-architecture](docs/07-ansible-roles-architecture.md)** ([PDF](docs/07-ansible-roles-architecture.pdf)) | Role-based automation architecture | Complete |
| **[08-windows-integration](docs/08-windows-integration.md)** ([PDF](docs/08-windows-integration.pdf)) | Windows automation and integration implementation | Complete |
| **[09-ansible-controller-setup](docs/09-ansible-controller-setup.md)** ([PDF](docs/09-ansible-controller-setup.pdf)) | Ansible controller bootstrap and configuration | Complete |
| **[10-proxmox-hypervisor](docs/10-proxmox-hypervisor.md)** ([PDF](docs/10-proxmox-hypervisor.pdf)) | Proxmox VE deployment, VLAN-aware bridge, trunk port migration | Complete |
| **[11-domain-controller-firewall](docs/11-domain-controller-firewall.md)** ([PDF](docs/11-domain-controller-firewall.pdf)) | pfSense aliases and rules for the DC01 domain controller: what each AD port does, how rules evaluate, target layout | In Progress |
| **[12-lab-expansion-roadmap](docs/12-lab-expansion-roadmap.md)** ([PDF](docs/12-lab-expansion-roadmap.pdf)) | Windows/AD estate growth plan: endpoint inventory, what each machine teaches, attack/defence scenarios, phased build, IAM repo decision | Planning |
| **[13-firewall-rulebase-governance](docs/13-firewall-rulebase-governance.md)** ([PDF](docs/13-firewall-rulebase-governance.pdf)) | Audit-grade rulebase governance: the 8 principles auditors check, a living rule register with per-rule justification and control mapping, change-control log, review cadence | In Progress |
| **[14-proxmox-storage-backup-capacity](docs/14-proxmox-storage-backup-capacity.md)** ([PDF](docs/14-proxmox-storage-backup-capacity.pdf)) | Proxmox storage layout, backup/recovery strategy (NIST CP-9), LXC-vs-VM capacity plan, and the lab-wide machine naming convention | Current |
| **[15-kali-attack-host-build](docs/15-kali-attack-host-build.md)** ([PDF](docs/15-kali-attack-host-build.pdf)) | Building the attack host on the isolated RedTeam segment, the containment evidence, and what the test does and does not prove about reachability | Current |
| **[16-siem01-build](docs/16-siem01-build.md)** ([PDF](docs/16-siem01-build.pdf)) | Recovering the SIEM after a hardware failure: the role swap that put Wazuh on dedicated hardware, the cloud-init and host-key traps, and where agent firewall rules belong | Current |
| **[17-domain-migration-corp-biirabank](docs/17-domain-migration-corp-biirabank.md)** ([PDF](docs/17-domain-migration-corp-biirabank.pdf)) | Moving the forest from `ad.biira.online` to `corp.biirabank.com`: why demote-and-repromote beat a rename, the lockout and its recovery, and a directory rebuild verified against the export | Current |
| **[18-public-web-presence-and-edge-hardening](docs/18-public-web-presence-and-edge-hardening.md)** ([PDF](docs/18-public-web-presence-and-edge-hardening.pdf)) | Building and hardening `biirabank.com` at the Cloudflare edge: the hosting decision, a bypass found and closed, TLS and header controls, and the F to A+ evidence from public graders | Current |
| **[19-vulnerability-scanning-scan01](docs/19-vulnerability-scanning-scan01.md)** ([PDF](docs/19-vulnerability-scanning-scan01.pdf)) | SCAN01 and Greenbone: the tool choice, three build failures recovered without data loss, and a least-privilege scan identity delivered by a scoped Group Policy that excludes domain controllers by design | In Progress |
| **[ssh-configuration](docs/ssh-configuration.md)** ([PDF](docs/ssh-configuration.pdf)) | SSH configuration and key management guide | Complete |
| **[troubleshooting](troubleshooting/)** | Comprehensive troubleshooting guides by component | Complete |

---

## Current Lab Infrastructure

![Network architecture](images/diagrams/network-architecture.png)

*Current-state architecture: Internet to pfSense, Switch 1 (Port 1 trunk to pfSense, Port 2 trunk to Switch 2, Ports 3 to 8 single-VLAN access), Switch 2 carrying the tagged VLANs to Proxmox, and the six security zones with their firewall status.*

### VLAN Architecture

| VLAN | Purpose | Subnet | Gateway | Services |
|------|---------|--------|---------|----------|
| **10 - Management** | Admin and Control | `192.168.10.0/24` | `.1` | pfSense, Ansible, Windows Systems, Proxmox |
| **20 - BlueTeam** | Security Monitoring | `192.168.20.0/24` | `.1` | SIEM01 (`192.168.20.2`), Wazuh 4.14.7 manager, indexer and dashboard |
| **30 - RedTeam** | Attack Simulation | `192.168.30.0/24` | `.1` | Kali Linux (Proxmox VM) |
| **40 - DevOps** | CI/CD Pipeline | `192.168.40.0/24` | `.1` | APP01 (`192.168.40.2`), application host. VAULT01 planned |
| **50 - EnterpriseLAN** | Business Services | `192.168.50.0/24` | `.1` | Windows Server 2025 domain controller (`192.168.50.2`) |
| **60 - Monitoring** | Observability | `192.168.60.0/24` | `.1` | Grafana and Prometheus, moving to a Proxmox guest |

### Deployed Systems

Machines follow a role-based naming convention, `<ROLE><NN>`: servers such as `DC01`, `CA01`, `SIEM01`, `MON01`, `VAULT01`, `ANS01`, `KALI01`, `WKS01`, and infrastructure such as `FW01` (pfSense), `SW01`/`SW02` (switches), `PVE01` (hypervisor) and `LAB01` (training host). The full scheme, the current rename status of every machine, and the reasoning behind the monitoring and SIEM role swap are in `docs/14` section 5.

| System | IP Address | VLAN | Platform | Purpose | Status |
|--------|------------|------|----------|---------|--------|
| pfSense Firewall | `192.168.10.1` | Management | FreeBSD | Gateway, firewall, Tailscale subnet router | Active |
| ANS01 (Ansible Controller) | `192.168.10.2` | Management | Ubuntu | Cross-platform automation | Rebuilding as a Proxmox guest |
| ADM01 (Admin laptop) | `192.168.10.3` | Management | Windows 11 | Administration workstation, Wazuh agent 002 | Active |
| TCM Ubuntu | `192.168.10.4` | Management | Ubuntu 24.04 | Training and development | Active |
| PVE01 (proxmox-01) | `192.168.10.6` | Management | Proxmox VE 9.2 (Debian 13) | Bare-metal VM hypervisor, Wazuh agent 003 | Active |
| SIEM01 | `192.168.20.2` | BlueTeam | Ubuntu 24.04 (Dell OptiPlex 9020, 8 core, 16 GB) | SIEM and centralised logging | Active, 3 agents reporting (DC01, ADM01, PVE01) |
| SCAN01 | `192.168.20.3` | BlueTeam | Ubuntu 26.04 (Proxmox VM 104) | Vulnerability scanning, Greenbone Community Edition | Active, feeds loaded (`docs/19`) |
| KALI01 | `192.168.30.2` | RedTeam | Kali Linux 2026.2 | Attack simulation (Proxmox VM 103) | Active, containment validated |
| APP01 | `192.168.40.2` | DevOps | Ubuntu | DevOps application host, two web apps behind Tailscale Serve | Active. VAULT01 will be a separate Proxmox guest |
| DC01 | `192.168.50.2` | EnterpriseLAN | Windows Server 2025 | Domain controller for `corp.biirabank.com` (AD DS + DNS) | Active, rebuilt 2026-09-07 (`docs/17`) |
| WKS01 | DHCP, VLAN 50 | EnterpriseLAN | Windows 11 Pro (Proxmox VM 100) | First domain-joined workstation, scan target | Active, joined 2026-09-11 |
| MON01 (Grafana + Prometheus) | `192.168.60.2` | Monitoring | Ubuntu | Observability dashboards | To be rebuilt as a Proxmox guest |

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
    |-- Port 6  VLAN 40 Access     APP01 application host (192.168.40.2)
    |-- Port 7  VLAN 50 Access     Windows Server 2025 DC (192.168.50.2)
    |-- Port 8  VLAN 60 Access     Monitoring segment
```

### Proxmox VM Hosting

Proxmox VE is connected to a trunk port carrying all VLANs, enabling VMs to be placed on any lab segment via a single VLAN-aware Linux bridge. A VM's network placement is determined solely by its VLAN Tag assignment at the virtual NIC level.

The host is an 8 core / 32 GiB / 2.67 TiB node with nightly backups to a dedicated second disk (see `docs/14`). Linux services are planned as LXC containers and Windows as full VMs, which keeps the estate within the memory budget.

| VM / CT | Bridge | VLAN Tag | Network | Purpose | Status |
|---------|--------|----------|---------|---------|--------|
| WKS01 (VM 100) | vmbr0 | 50 | DHCP | Domain-joined Windows 11 workstation | Active |
| KALI01 (VM 103) | vmbr0 | 30 | 192.168.30.2 | RedTeam attack simulation | Active, containment validated |
| SCAN01 (VM 104) | vmbr0 | 20 | 192.168.20.3 | Greenbone vulnerability scanner, a Tier 0 VM | Active |
| ANS01 | vmbr0 | 10 | 192.168.10.2 (same IP) | Fresh rebuild of the automation controller | Planned |
| MON01 | vmbr0 | 60 | 192.168.60.2 | Grafana and Prometheus, rebuilt fresh | Planned |
| DC02, CA01, WKS02 | vmbr0 | 50 / client | see `docs/12` | AD estate expansion for security training | Roadmap |

---

## Lab Capabilities

### Operational Capabilities

- **Virtualisation**: Proxmox VE node with multi-VLAN VM hosting across all lab segments, plus nightly backups to a dedicated disk
- **Identity Services**: Active Directory (`corp.biirabank.com`) on DC01 with AD-integrated DNS, one domain-joined workstation, and a least-privilege scan identity delivered by Group Policy (`docs/17`, `docs/19`)
- **Network Segmentation**: six VLANs; three with explicit default-deny rulesets, three still permissive
- **Remote Operations**: access to lab resources via Tailscale mesh VPN
- **Scalability**: Proxmox enables rapid deployment of new VMs on any VLAN without physical changes
- **Security Monitoring**: Wazuh on SIEM01 with agents on DC01, ADM01 and PVE01 (`docs/16`)
- **Vulnerability Scanning**: Greenbone Community Edition on SCAN01 with 186,567 vulnerability tests loaded (`docs/19`)
- **Not yet running**: Ansible, while the controller is rebuilt as ANS01, and Grafana and Prometheus, until MON01 is rebuilt

### Security Posture

- **Default-Deny Segmentation**: MANAGEMENT, ENTERPRISELAN and REDTEAM run explicit least-privilege rulesets; every rule carries a business justification and a NIST control mapping (`docs/13`)
- **Management-Plane Isolation**: verified by test. VLAN 50 cannot reach the pfSense administrative interface on any interface, while retaining the DNS, NTP and internet access it legitimately needs
- **Attack-Segment Containment**: RedTeam (VLAN 30) has no standing path to the domain controller or any other VLAN. Exercise access is granted temporarily and withdrawn afterwards
- **Change Control**: firewall changes are logged with tester, rollback and validation evidence, and controls are re-tested before and after each change
- **Backup and Recovery**: nightly Proxmox backups to a separate physical disk, with documented restore procedure (NIST CP-9)
- **Software Integrity**: installation media verified by SHA256 before use (NIST SI-7)
- **Secure Remote Access**: WireGuard encryption via Tailscale. Its ability to bypass per-interface rules is recorded as a known, risk-accepted hardening item (H-02)


---

## Development Roadmap

### Phase 1: Foundation (Complete)

- Network infrastructure with 6-VLAN segmentation
- Security monitoring with Wazuh SIEM
- Cross-platform automation with Ansible
- Remote access via Tailscale mesh VPN
- Observability stack with Grafana and Prometheus

### Phase 2: Virtualisation and Advanced Security (In Progress)

Complete:

- Proxmox VE hypervisor deployed with VLAN-aware trunk port configuration
- DC01 (Windows Server 2025) promoted as domain controller, then migrated to a new forest, `corp.biirabank.com`, with the directory rebuilt and verified against an export (`docs/17`)
- pfSense rulebase hardened on three interfaces: MANAGEMENT (MGMT-01 to 10), ENTERPRISELAN (ENT-01 to 04) and REDTEAM (RED-01 to 03), each rule justified and control-mapped
- Management-plane isolation proven by before and after testing (`docs/13` section 3.1)
- KALI01 (Kali Linux) built on VLAN 30 and its containment validated against a live host: no reachability to the domain controller or the firewall management plane, while DNS, time and internet all function (`docs/15`)
- Nightly Proxmox backups to a dedicated second disk, verified by an on-demand restore point
- Wazuh on SIEM01 after the role swap with the monitoring hardware, with agents on DC01, ADM01 and PVE01 and CIS baselines recorded (`docs/16`)
- `biirabank.com` published and hardened at the Cloudflare edge, graded A+ (`docs/18`)
- SCAN01 running Greenbone, with a least-privilege scan identity delivered by Group Policy and proven on the first domain-joined workstation (`docs/19`)

In progress:

- Ansible controller rebuild as ANS01 (Proxmox guest, retaining `192.168.10.2`)
- First credentialed and unauthenticated scans, and the BlueTeam ruleset they require (`docs/19` section 7)
- MON01 rebuild as a Proxmox guest, replacing the physical monitoring host

Remaining:

- BlueTeam, DevOps and Monitoring VLAN rulesets (still permissive)
- Tailscale scoping (hardening item H-02)
- Wazuh agent deployment across all platforms, custom detection rules, and security dashboards

### Phase 3: Red Team Capabilities (Started)

- Kali Linux operational on VLAN 30 and contained (`docs/15`)
- Attack simulation and penetration testing environment
- Purple team exercise frameworks
- Security tool development and testing environment

### Phase 4: DevSecOps Integration (Future)

- CI/CD pipeline integration with security scanning
- Infrastructure as Code enhancement
- Automated compliance checking and reporting
- Advanced automation workflows and orchestration

---





## Current State

**In place:** an Active Directory forest, `corp.biirabank.com`, behind a pfSense rulebase converted from permissive any-to-any rules to explicit, least-privilege, control-mapped rulesets on three interfaces. Management-plane isolation and RedTeam containment are enforced and evidenced by repeatable tests (`docs/13`, `docs/15`). Wazuh monitors the domain controller, the hypervisor and the admin workstation (`docs/16`). Greenbone is deployed with a scan identity that is administrator on member machines and nothing else (`docs/19`). Proxmox hosts the growing estate with nightly backups to a separate disk.

**Not yet in place:** three of the six VLANs still carry permissive rules, the Ansible controller and the metrics stack are awaiting rebuild, and no credentialed scan has run yet. These gaps are stated here and in the chapters rather than presented as complete.
