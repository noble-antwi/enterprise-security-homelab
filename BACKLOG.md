# Backlog and Current State

The working list for this lab. Documentation in `docs/` records what was built and why; this file records **what is true right now and what comes next**, so work can be picked up without reconstructing context.

**Updated:** 2026-09-11

---

## Current state

| Area | Status |
|------|--------|
| Network | pfSense, 6 VLANs, 2 switches, Proxmox on a VLAN-aware trunk |
| Firewall | MANAGEMENT, ENTERPRISELAN and REDTEAM have explicit rulesets. BLUETEAM, DEVOPS and MONITORING are still `any→any` |
| Identity | DC01 live on **`corp.biirabank.com`** (NetBIOS `CORP`), rebuilt 2026-09-07. 20 OUs, 32 users and 12 security groups restored from export. `ad.biira.online` retired. **WKS01 joined 2026-09-11**, the first member since the rebuild, into the pre-staged account in `BIIRA\Computers\Workstations` |
| Vulnerability scanning | SCAN01 running Greenbone CE, 186,567 vulnerability tests loaded, all four feeds loaded (confirmed 2026-09-11). Snapshot and a weekly feed refresh outstanding. Scan identity `svc-greenbone` and group `SG-Scanner-LocalAdmin` built 2026-09-09, policy `SEC-Scanner-Access` 2026-09-11. No credentialed scan yet. `docs/19` |
| Public web | **`biirabank.com` live**, Cloudflare Worker static assets. HTTPS enforced, TLS 1.2 minimum, six security headers, zero-JavaScript CSP. securityheaders.com **A+** |
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
| SCAN01 | `192.168.20.3` | 20 | none | Greenbone CE, Tier 0 VM 104. `docs/19` |
| KALI01 | `192.168.30.2` | 30 | none | Attack box, contained |
| APP01 | `192.168.40.2` | 40 | none | Two web apps behind Tailscale Serve |
| DC01 | `192.168.50.2` | 50 | 001 | Domain controller, `corp.biirabank.com`. Agent 001 to be reconfirmed after the rebuild |
| WKS01 | `192.168.50.56` (DHCP) | 50 | none | VM 100, Windows 11 Pro. **Joined `corp.biirabank.com` 2026-09-11** into its pre-staged account in `BIIRA\Computers\Workstations`. DNS pointed at DC01 by hand |

---

## Next up

**0. WKS01, then the scanner's first credentialed scan.** `SEC-Scanner-Access` is proven on WKS01 (2026-09-11). Add the logon-rights restrictions to the policy after reading WKS01's existing values, snapshot SCAN01 now its feeds are loaded, then scan. Full list in `docs/19` section 7.

**1. `DEV-01` and a Wazuh agent on APP01.** APP01 is the only host with no monitoring. The rule goes on the **DEVOPS** tab because that is where its traffic originates: source `DEVOPS subnets`, destination `SIEM01_HOST`, ports `WAZUH_AGENT`. First real rule on that interface.

**2. Finish the domain migration tail.** The forest is rebuilt but three things trail it: recreate the reverse DNS zone for `192.168.50.0/24` so logs show hostnames rather than addresses, rejoin the machines that were bound to the retired `ad.biira.online` (WKS01 joined fresh 2026-09-11; no older machine has rejoined), and reconfirm Wazuh agent 001 is reporting from the rebuilt controller. See `docs/17` section 7.

**3. Harden DC01 against its CIS baseline.** 26% recorded before any changes (`docs/16` section 10). Note the baseline predates the rebuild, so re-run the assessment first to get a current figure. Then pick a set of failing checks, apply, re-run, record the delta. A score that moves is the evidence; a score on its own is not.

**4. Enforce the tiered admin model with Group Policy.** Deny Domain Admins every logon type on member workstations and servers (joining adds `CORP\Domain Admins` to every member's local Administrators, seen on WKS01). Include delegating *join computers to the domain* on the Workstations OU to a Tier 2 group: WKS01 was joined with `CORP\Administrator`, a Tier 0 credential typed on a Tier 2 machine (`docs/19` 6.3). The `Tier0` / `Tier1` / `Tier2` organisational units and their matching `SG-` groups exist, but nothing enforces the tier restrictions. Structure without enforcement. Found during the migration export, recorded in `docs/17` section 2.

---

## Backlog

### Hardening

- **DC01** against CIS Windows Server 2025. Baseline 26%, 293 failing checks
- **ADM01** against CIS Windows 11 Enterprise. Baseline 26%, 348 failing. Matters as much as DC01, because domain credentials are typed on it
- **PVE01** against CIS Debian 13. Baseline 43%
- **SIEM01** against CIS Ubuntu 24.04. Baseline 53.6%
- Disable SSH password authentication across Linux hosts, key-based only

### Vulnerability management

- **SCAN01**: built 2026-09-08 as a Proxmox **VM** (not LXC) on VLAN 20, `192.168.20.3`, Ubuntu 26.04, 2 vCPU, 60 GB disk, later grown to 100 GB after the feeds filled it twice (`docs/19` section 4). Raised to 8 GB for Greenbone. VM rather than container because the scanner is a **Tier 0 asset**: it stores administrative credentials for every host it scans, so it gets a hardware isolation boundary. Rule recorded in `docs/14` section 4. Originally built as `NESSUS01` and renamed, because the convention names roles, not products
- **Greenbone Community Edition is the scanner.** Deployed as the Greenbone Community Containers via Docker Compose, which is the supported route for CE. Unlimited targets, no expiry, fully open source
- **Nessus Essentials was evaluated and rejected**, 2026-09-08. Current terms are **5 IPs on a 30-day licence**, not the 16-IP perpetual licence it once had. Five of nine hosts cannot demonstrate estate coverage, which is the point of vulnerability management, and a licence that expires in a month cannot support a remediation loop that depends on before-and-after comparison. Tenable interface familiarity is obtainable from a trial in an afternoon if a specific role asks for it, and is not worth structuring the lab around
- **Bind the Greenbone web interface to `192.168.20.3:9392`**, not `0.0.0.0`. The default compose file binds to localhost only; the fix is to name the interface explicitly rather than open it to everything. Same mistake as `iam-job-scout-web-1` on APP01
- **Docker group membership is equivalent to root** on this host, because a container can mount the host filesystem. On a Tier 0 asset that is worth a deliberate decision rather than a convenience default
- **Done 2026-09-09 (account, group) and 2026-09-11 (policy): the scan identity.** `svc-greenbone` (cannot be delegated, cannot change its password, password never expires as a recorded debt), in `SG-Scanner-LocalAdmin`, which `SEC-Scanner-Access` adds to local Administrators on members only. Linked to `BIIRA\Computers`, never the Domain Controllers OU. Credentials eventually issued by VAULT01, logins shipped to Wazuh. Same non-human identity pattern as the AI agent scenario, rehearsed on a service that exists first. `docs/19` sections 5 and 6
- **Proven on WKS01 2026-09-11:** `gpresult` lists `SEC-Scanner-Access`, and `CORP\SG-Scanner-LocalAdmin` is in WKS01's local Administrators. Still open: the logon-rights restrictions
- **Domain controllers are scanned unauthenticated**, with Wazuh SCA covering their configuration. No least-privilege credential exists for a DC, so none is issued
- Write the **BLUETEAM ruleset** around what the scanner actually needs. The scanner dials out to everything, so this is the first genuine reason to write rules on that tab
- Note on **overlap with Wazuh**: Wazuh already performs credentialed, agent-based CVE detection from package inventory across the estate, and it found 22 critical and 120 high on PVE01. A network scanner is not duplicating that. What it adds is the **outside perspective**: which ports actually answer, which services are exposed across VLANs, weak TLS, default credentials. Both are needed, and the distinction is worth stating in the write-up
- **DefectDojo** once there are two sources of findings to aggregate. This is the management layer that turns findings into a process, which is what PCI-DSS 11.3 and NIST RA-5 actually assess

### Rebuilds

- **MON01** on Proxmox, VLAN 60, `192.168.60.2`. Grafana and Prometheus installed fresh, no state migrated. Repurpose VM 102
- **ANS01** on Proxmox, VLAN 10, `192.168.10.2`. After the Ansible course
- **VAULT01** on Proxmox, VLAN 40, as a **VM not an LXC**. Deliberately not on APP01: Vault holds every secret in the environment and should not share a host with a web application. Tier 0 by the same test as the scanner, so it gets hardware isolation rather than a shared kernel. Store the unseal keys **outside** the machine and outside the backup
- **PAW01**, a dedicated administrative workstation, which is the proper resolution to `H-01`

### Firewall

- **VLAN 50 DHCP hands out public DNS.** Found 2026-09-11 on WKS01: `8.8.8.8`, `1.1.1.1` and a `duckdns.org` suffix, so no new Windows client can find the domain. In pfSense DHCP for ENTERPRISELAN, set DNS to `192.168.50.2`, domain to `corp.biirabank.com`, and add a static mapping for WKS01. `docs/19` section 6.3
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
- **Done 2026-09-07: upgraded to Ubuntu 26.04.1 LTS** (codename resolute, kernel 7.0). The virtualenv was rebuilt against Python 3.14, which required installing `python3.14-venv` first. Both applications and all three containers returned
- Physical host, so **no Proxmox backup covers it**. If the application data matters, that needs solving separately
- Note for future work on this host: **Stock Copilot is supervised by a user-level systemd service**, not a system one, with `Linger=yes` so it starts at boot without a login. It runs two processes, `--serve` on 8765 and `--poll-alerts`. Check `systemctl --user list-units` before assuming anything about how a service on this machine is managed

### Public web and edge

Detail in `docs/18`.

- **SSL Labs** grade capture, a second independent scoreboard for the TLS work
- **SPF, DMARC and null-MX** records on `biirabank.com` so the domain cannot be used to spoof email, per `ADR-001`
- **WAF managed rules** on, with a Security Events screenshot showing a real blocked request
- Screenshots owed: the Transform Rule with its six headers, the TLS minimum setting, the `workers.dev` routes disabled
- Later: the **Okta sign-in hand-off** from the site to `corp.biirabank.com`, which closes the identity chain from the public internet to the on-premises directory

### Documentation debt

- `docs/08` and `docs/11` reference `ad.biira.online`, retired 2026-09-07. Update to `corp.biirabank.com` when those chapters are next revised
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
