# Backlog and Current State

The working list for this lab. Documentation in `docs/` records what was built and why; this file records **what is true right now and what comes next**, so work can be picked up without reconstructing context.

**Updated:** 2026-09-06

---

## Current state

| Area | Status |
|------|--------|
| Network | pfSense, 6 VLANs, 2 switches, Proxmox on a VLAN-aware trunk |
| Firewall | MANAGEMENT, ENTERPRISELAN and REDTEAM have explicit rulesets. BLUETEAM, DEVOPS and MONITORING are still `any→any` |
| Identity | DC01 live, `ad.biira.online`, AD DS and DNS healthy |
| SIEM | SIEM01 running Wazuh 4.14.7. Four hosts assessed, three agents reporting |
| Attack segment | KALI01 built and containment validated |
| Monitoring | **None.** Grafana and Prometheus removed from the old host, MON01 not yet rebuilt |
| Automation | **None.** ANS01 destroyed, rebuild pending |
| Secrets | **None.** VAULT01 not yet built |
| Backups | Proxmox guests backed up nightly to a second disk. Physical hosts are not |

### Hosts

| Host | Address | VLAN | Wazuh agent | Notes |
|------|---------|------|-------------|-------|
| FW01 (pfSense) | `192.168.10.1` | all | n/a | Rename pending |
| ADM01 | `192.168.10.3` | 10 | 002 | Admin laptop. To be superseded by PAW01 |
| LAB01 (TCM Ubuntu) | `192.168.10.4` | 10 | none | Rename pending |
| PVE01 (proxmox-01) | `192.168.10.6` | 10 | 003 | Node rename pending, carries risk |
| SIEM01 | `192.168.20.2` | 20 | manager (000) | Wazuh manager, indexer, dashboard |
| KALI01 | `192.168.30.2` | 30 | none | Attack box, contained |
| APP01 | `192.168.40.2` | 40 | none | Two web apps behind Tailscale Serve |
| DC01 | `192.168.50.2` | 50 | 001 | Domain controller |

---

## Next up

**1. Upgrade APP01 to Ubuntu 26.04 LTS.** Still running 25.10, which is end of life and receiving no security updates. It is reachable over Tailscale and serves two web applications, which makes it the weakest position in the estate. `sudo do-release-upgrade`. Note that `apt upgrade` alone does not do this; the release upgrade is a separate command.

**2. `DEV-01` and a Wazuh agent on APP01.** APP01 is the only host with no monitoring. The rule goes on the **DEVOPS** tab because that is where its traffic originates: source `DEVOPS subnets`, destination `SIEM01_HOST`, ports `WAZUH_AGENT`. First real rule on that interface.

**3. Harden DC01 against its CIS baseline.** 26% recorded before any changes (`docs/16` section 10). Pick a set of failing checks, apply, re-run the assessment, record the delta. A score that moves is the evidence; a score on its own is not.

---

## Backlog

### Hardening

- **DC01** against CIS Windows Server 2025. Baseline 26%, 293 failing checks
- **ADM01** against CIS Windows 11 Enterprise. Baseline 26%, 348 failing. Matters as much as DC01, because domain credentials are typed on it
- **PVE01** against CIS Debian 13. Baseline 43%
- **SIEM01** against CIS Ubuntu 24.04. Baseline 53.6%
- Disable SSH password authentication across Linux hosts, key-based only

### Vulnerability management

- **Nessus Essentials** as a Proxmox guest on VLAN 20. Free for 16 IPs, and the industry reference
- Write the **BLUETEAM ruleset** around what the scanner actually needs. The scanner dials out to everything, so this is the first genuine reason to write rules on that tab
- **Greenbone / OpenVAS** as a fully open-source alternative, later
- **DefectDojo** once there are two sources of findings to aggregate. This is the management layer that turns findings into a process, which is what PCI-DSS 11.3 and NIST RA-5 actually assess

### Rebuilds

- **MON01** on Proxmox, VLAN 60, `192.168.60.2`. Grafana and Prometheus installed fresh, no state migrated. Repurpose VM 102
- **ANS01** on Proxmox, VLAN 10, `192.168.10.2`. After the Ansible course
- **VAULT01** on Proxmox, VLAN 40. Deliberately not on APP01: Vault holds every secret in the environment and should not share a host with a web application. Store the unseal keys **outside** the machine and outside the backup
- **PAW01**, a dedicated administrative workstation, which is the proper resolution to `H-01`

### Firewall

- BLUETEAM ruleset, driven by the scanner's needs
- DEVOPS ruleset, starting with `DEV-01`
- MONITORING ruleset, once MON01 exists. Prometheus dials **out** to scrape, so its rules go on the MONITORING tab
- **H-02**: scope the Tailscale rules, or move that control into Tailscale ACLs where device identity decides rather than network location
- **H-01**: `ADMIN_HOSTS` alias, and narrow `MGMT-08` to it once PAW01 exists
- **H-03**: review the dormant `ansible` account on SIEM01 when ANS01 returns

### Renames

Convention in `docs/14` section 5.

- pfSense → `FW01` (System, General Setup, Hostname)
- TL-SG108E → `SW01`, secondary switch → `SW02`
- TCM Ubuntu → `LAB01`
- Proxmox VM display names: VM 100 → `WKS01`, VM 102 → `MON01`
- `proxmox-01` → `PVE01`. **Do this last, after a backup.** Guest configs live under `/etc/pve/nodes/<name>/`, so the rename moves a directory inside the cluster filesystem

### Automation

- Ansible course
- Practice targets: two throwaway LXC containers on VLAN 10, `LAB-T1` and `LAB-T2`. Break them freely, roll back
- First real role: **deploy the Wazuh agent**. By then it will have been done by hand on Windows, Debian and Ubuntu, so the role will handle what actually happens
- Habits from day one: `--check --diff` before applying, `--limit` to one host, never `all` while learning, snapshot anything virtual, treat physical hosts as production

### APP01 follow-ups

- **`iam-job-scout-web-1` is bound to `0.0.0.0:5000`**, unlike the other two containers which listen on `127.0.0.1` and are reached only through Tailscale Serve. It is therefore directly reachable from anything that can route to `192.168.40.2` and from the whole tailnet. Bind it to localhost and put it behind Serve like the others, unless the exposure is deliberate
- **Re-enable the third-party apt repositories** after the release upgrade: `azure-cli`, `github-cli`, `hashicorp`, `tailscale`. `do-release-upgrade` disables them, and they will point at the old Ubuntu codename afterwards, so packages keep working but stop receiving updates
- **Rebuild the Stock Copilot virtualenv** if the system Python moved: `python3 -m venv --clear .venv` then reinstall requirements. The venv's interpreter is a symlink to the system `python3.13`
- Physical host, so **no Proxmox backup covers it**. If the application data matters, that needs solving separately

### Documentation debt

- `docs/02` describes the failed Rocky Linux Wazuh host. Superseded by `docs/16`
- `docs/08` and `docs/09` describe the retired Windows Server 2022 setup
- `docs/03` describes Grafana and Prometheus on the old host. Rewrite when MON01 exists
- Legacy `images/image-*.png` files still referenced by older docs, to be replaced area by area

### Longer term

- **AI agent identity governance.** Give an agent a scoped service account in AD, issue it a short-lived credential from VAULT01, restrict its reach with firewall rules, and ship every action to Wazuh so it is attributable. Waiting on VAULT01 and the IAM lab
- DC02, CA01, WKS01 and WKS02, per `docs/12`
- Purple team exercises from KALI01 with detections in Wazuh

---

## Evidence owed

- Screen recording of the PVE01 agent install. Attempted, abandoned after three consecutive platform failures, all now documented in `docs/16`. Worth re-recording as a clean run
- Screenshots of the DEVOPS ruleset once `DEV-01` exists
- Before and after assessment screenshots for the DC01 hardening

Recording policy is in `images/README.md`: raw video stays out of the repository, a still frame is committed, and the video is linked from the document it belongs to.
