<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/brand/biira-bank-lockup-reverse-960.png">
  <img src="images/brand/biira-bank-lockup-960.png" alt="Biira Bank" width="300">
</picture>

# Skills Matrix

What this lab has actually taught me, and where the proof is.

Every row below points at a document that describes the work and a folder of
screenshots taken while doing it. Nothing is listed because I read about it.
If a capability is claimed here, something in this repository shows it
running, failing, or being fixed.

[![Chapters](https://img.shields.io/badge/chapters-19-brightgreen.svg)](docs/)
[![Evidence](https://img.shields.io/badge/screenshots-150%2B-blue.svg)](images/)
[![Scenario](https://img.shields.io/badge/scenario-corp.biirabank.com-08152F.svg)](README.md)

## How to read this

| Mark | Meaning |
|:---:|---|
| ● | Built it, it runs, I can rebuild it from memory |
| ◐ | Built it, but I still reach for notes or help |
| ○ | Next up, not started |

The `◐` rows are the honest ones. They are where the work is.

---

## Network segmentation and firewalling

| Capability | What I did | Proof | |
|---|---|---|:---:|
| VLAN design and enforcement | Six segments on pfSense with an explicit rule set per interface, not a flat network with a firewall bolted on | [docs/01](docs/01-network-infrastructure.md), [images/net](images/net/) | ● |
| Stateful rule evaluation | Learned that rules are judged on the interface the first packet **enters**, and that replies come back on state rather than on a matching rule. This is the single fact that makes multi-VLAN troubleshooting possible | [docs/11](docs/11-domain-controller-firewall.md), [images/fw](images/fw/) | ● |
| Rule base governance | A living rule register: every rule carries a justification, an owner and a control mapping, with a change log and a review cadence. Written to survive an audit rather than to work | [docs/13](docs/13-firewall-rulebase-governance.md) | ● |
| Per-service AD port rules | Opened Active Directory to the network port by port, knowing what each one carries, instead of allowing the DC wholesale | [docs/11](docs/11-domain-controller-firewall.md), [images/fw](images/fw/) | ● |
| DNS resolver operation | Unbound with domain overrides, and the outgoing-interface setting that silently breaks resolution when the resolver may only speak out of WAN | [docs/17](docs/17-domain-migration-corp-biirabank.md) | ● |
| Segment containment testing | Proved the RedTeam segment cannot reach the rest of the estate, and kept the evidence | [docs/15](docs/15-kali-attack-host-build.md), [images/red](images/red/) | ● |

## Identity and Active Directory

| Capability | What I did | Proof | |
|---|---|---|:---:|
| Forest build and migration | Moved the estate from `ad.biira.online` to `corp.biirabank.com` by demote and repromote rather than a rename, recovered a lockout mid-migration, and verified the rebuilt directory against an export | [docs/17](docs/17-domain-migration-corp-biirabank.md), [images/dc](images/dc/) | ● |
| Tiered OU and group structure | An OU layout that reflects administrative tiers, so that delegation has something to attach to | [docs/17](docs/17-domain-migration-corp-biirabank.md) | ● |
| Group Policy as the delivery mechanism | Local group membership, service state and firewall rules pushed by GPO rather than configured by hand, so a second machine inherits them for free | [docs/19](docs/19-vulnerability-scanning-scan01.md), [images/scan](images/scan/) | ● |
| Group Policy Preferences vs Restricted Groups | Preferences with action Update **adds** to a local group. Restricted Groups **replaces** it. Choosing wrong removes Domain Admins from every machine in scope | [docs/19](docs/19-vulnerability-scanning-scan01.md) | ● |
| User Rights Assignment | A defined right **replaces** the machine's existing list, Not Defined preserves it, and deny always beats allow | [docs/19](docs/19-vulnerability-scanning-scan01.md) | ◐ |
| Least-privilege service accounts | `svc-greenbone` exists to do exactly one job, is denied every interactive logon type, and is marked sensitive so its ticket cannot be delegated | [docs/19](docs/19-vulnerability-scanning-scan01.md), [images/scan](images/scan/) | ● |
| Windows logon types | Reading type 2, 3, 4, 5 and 10 in event data, and knowing which deny right blocks which | [docs/19](docs/19-vulnerability-scanning-scan01.md) | ◐ |
| Automation service accounts | A separate constrained identity for Ansible, with its WinRM path documented | [docs/06](docs/06-ansible-service-account.md), [docs/08](docs/08-windows-integration.md) | ● |

## Endpoint telemetry and detection

| Capability | What I did | Proof | |
|---|---|---|:---:|
| SIEM deployment and recovery | Rebuilt Wazuh onto dedicated hardware after a failure, including the cloud-init and host-key traps that broke the first attempt | [docs/16](docs/16-siem01-build.md), [images/siem](images/siem/) | ● |
| Agent estate and shared config | Four agents, grouped, with configuration delivered through a shared `agent.conf` rather than edited per host | [docs/16](docs/16-siem01-build.md), [images/siem](images/siem/) | ● |
| Sysmon deployment | Installed and configured on three Windows endpoints with a curated config, and collected centrally | [images/sys](images/sys/) | ● |
| Reading Sysmon events | Event 1 process creation with parent command line, 3 network, 11 file create, 22 DNS. Knowing what each one is good for | [images/sys](images/sys/) | ◐ |
| CIS configuration assessment | Benchmark scoring running against Windows endpoints | [images/siem](images/siem/) | ◐ |
| Custom rule authoring and tuning | Silenced a level 15 false positive without going blind to the real thing, pinning two fields so the exclusion cannot be walked through, and inverted the scanner rule so unexpected use of the scan account is now louder than it was | [docs/20](docs/20-detection-engineering-tuning-and-archives.md), [detections/](detections/README.md) | ◐ |
| Alert triage | Took one alert from "this looks bad" to a decision: read the rule metadata, worked out what the host was really doing, and proved the fix on live data rather than in a test harness | [docs/20](docs/20-detection-engineering-tuning-and-archives.md) | ◐ |
| Log pipeline and retention | Enabled archives across three systems in the right order, measured the growth, reverted the duplicate writer, and planned retention against what the indexer actually costs | [docs/20](docs/20-detection-engineering-tuning-and-archives.md) | ◐ |

## Vulnerability management

| Capability | What I did | Proof | |
|---|---|---|:---:|
| Scanner build and operation | Greenbone on a Tier 0 VM, feed synchronisation, targets, credentials and tasks | [docs/19](docs/19-vulnerability-scanning-scan01.md), [images/scan](images/scan/) | ● |
| Unauthenticated vs credentialed scanning | A scan that "succeeds" with 4 applications and 0 CVEs is telling you the credential path is broken, not that the host is clean | [docs/19](docs/19-vulnerability-scanning-scan01.md) | ● |
| The credentialed scan chain | Admin rights, then SMB 445 through the host firewall, then the Remote Registry service. Break any link and the scan still reports success while seeing nothing | [docs/19](docs/19-vulnerability-scanning-scan01.md), [images/scan](images/scan/) | ● |
| Scanner identity design | A scan account scoped to one source host, with the host firewall rule scoped to that address and profile rather than opened to the subnet | [images/scan](images/scan/) | ● |
| Reading a scan report | Results, hosts, ports, applications, operating systems and CVEs as a set of cross-checks on each other | [docs/19](docs/19-vulnerability-scanning-scan01.md) | ◐ |

## Virtualisation and platform

| Capability | What I did | Proof | |
|---|---|---|:---:|
| Bare-metal hypervisor | Proxmox VE with a VLAN-aware bridge and a trunk port migration, hosting guests across multiple segments | [docs/10](docs/10-proxmox-hypervisor.md), [images/pve](images/pve/) | ● |
| Storage and backup planning | Storage layout, a backup and recovery strategy mapped to NIST CP-9, and an LXC versus VM capacity plan | [docs/14](docs/14-proxmox-storage-backup-capacity.md) | ● |
| Placement decisions | Which workloads earn a VM and which stay physical, argued rather than assumed | [docs/14](docs/14-proxmox-storage-backup-capacity.md) | ● |
| Remote access | Tailscale mesh across the estate | [docs/05](docs/05-remote-access.md) | ● |

## Automation

| Capability | What I did | Proof | |
|---|---|---|:---:|
| Cross-platform configuration management | Ansible driving both Linux and Windows hosts from one controller | [docs/04](docs/04-automation-platform.md), [docs/09](docs/09-ansible-controller-setup.md) | ● |
| Role-based structure | Playbooks decomposed into reusable roles instead of one monolith, with the monolithic versions kept for comparison | [docs/07](docs/07-ansible-roles-architecture.md), [ansible/](ansible/) | ● |
| Windows automation over WinRM | Listener configuration, the service account, and verification playbooks | [docs/08](docs/08-windows-integration.md) | ● |

## Public edge and web

| Capability | What I did | Proof | |
|---|---|---|:---:|
| Edge hardening | `biirabank.com` on Cloudflare with Full Strict TLS, HTTPS only, a six-header transform rule and a zero-JavaScript strict CSP | [docs/18](docs/18-public-web-presence-and-edge-hardening.md) | ● |
| Finding my own bypass | Discovered the `workers.dev` hostname served the same content outside the hardened zone, and closed it | [docs/18](docs/18-public-web-presence-and-edge-hardening.md) | ● |
| Independent verification | F to A+ on public graders, captured as evidence rather than claimed | [docs/18](docs/18-public-web-presence-and-edge-hardening.md), [images/web](images/web/) | ● |

## Operations and governance

| Capability | What I did | Proof | |
|---|---|---|:---:|
| Architecture decision records | Decisions written down with the alternatives and the reasoning, so a later me can tell whether they still hold | [docs/decisions](docs/decisions/) | ● |
| Naming convention | One lab-wide convention for machines, applied consistently | [docs/14](docs/14-proxmox-storage-backup-capacity.md) | ● |
| Evidence discipline | Screenshots taken at the moment of the change, named by area and sequence, checked for credentials before they are committed | [images/README](images/README.md) | ● |
| Documenting failure | The lockout, the dead SIEM, the broken resolver and the bypass are all written up. The failures are the part worth reading | [docs/16](docs/16-siem01-build.md), [docs/17](docs/17-domain-migration-corp-biirabank.md) | ● |

---

## Four things that changed how I work

**A tool that reports success can still be blind.** The first credentialed scan
returned cleanly: one host up, three ports, zero errors. It had also found four
applications and zero vulnerabilities on a live Windows workstation, which is
impossible. The report was not lying, it was answering a narrower question than
the one I thought I had asked. Now I check what a clean result would have to
look like before I believe one.

**Change one thing at a time.** Two DNS settings were changed together, name
resolution broke, and neither change was the cause. The real cause was a third
setting neither of us had looked at. An hour was lost to having no way to
attribute the failure.

**Security settings tattoo.** Policy applied through the security half of Group
Policy persists after the GPO is unlinked. Unlinking is not undoing, and a lab
is a cheap place to learn that.

**A failing rule is silent.** A Wazuh regex written against single backslashes
never matches, because Sysmon delivers Windows paths with them doubled. No
error, no warning, just a rule that quietly never fires. Detection logic has to
be tested against a real event, not reasoned about.

---

## Currently building

| Next | Why |
|---|---|
| Wazuh rule authoring without help | Writing detection logic end to end, from a raw event to a tested rule, is the core SOC engineering skill and I am not there yet |
| A tuned alert baseline | One credentialed scan produced 2,051 alerts from a single rule. An alert queue nobody can read protects nothing |
| Purple team loop | Run an attack from the RedTeam segment, watch what the SIEM does and does not see, then close the gap and prove it |
| DefectDojo | Findings tracked over time with a remediation history, once there are three scan reports and at least one fix to show |
| VAULT01 | Secrets out of documents and into a secrets manager, which several other pieces of work are waiting on |

Roadmap detail in [docs/12](docs/12-lab-expansion-roadmap.md).
