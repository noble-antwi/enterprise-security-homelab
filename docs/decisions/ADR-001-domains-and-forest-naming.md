# ADR-001: Public domains and Active Directory forest naming for the rebuild

| | |
|---|---|
| **Status** | Accepted, 7 September 2026 |
| **Decided by** | Noble Antwi |
| **Applies to** | enterprise-security-homelab and enterprise-iam-lab (both repositories) |
| **Supersedes** | The `biira.online` domain and the `ad.biira.online` forest documented in earlier phases |

## Context

The first build of the Biira Bank lab used the public domain `biira.online` (Active Directory forest `ad.biira.online`, Okta custom domain `login.biira.online`). Two things happened:

1. `biira.online` is being retired. Its renewal price is high, and `.online` renewals are set by the registry with no cap.
2. The Okta Integrator (developer) organisation that hosted the identity lab was deactivated after a period without a login. Integrator orgs cannot be recovered; a new one must be created.

Together these mean the identity estate is rebuilt from the ground up, and the domain controller is rebuilt with it. That makes this the one moment where the naming can be chosen with no migration cost.

Two domains were registered on 7 September 2026 at Cloudflare Registrar (sold at cost, renewals at the same price):

| Domain | Purpose | Renewal |
|---|---|---|
| `nobleantwi.com` | Noble's personal site (noble-antwi.github.io moves there). Not part of the lab. | $10.46/yr |
| `biirabank.com` | The Biira Bank organisation: public identity, Okta and Entra custom domains, email authentication, TLS for lab services. | at cost |

## Decision

### 1. Public domain: `biirabank.com`

Everything the organisation presents to the outside world uses `biirabank.com`:

- Okta custom domain: `login.biirabank.com`
- Microsoft Entra ID custom domain: `biirabank.com` (TXT verification at Cloudflare)
- Any public-facing lab service with a real certificate: `<service>.biirabank.com`
- Email authentication records, even though the domain sends no mail (see section 5)

DNS for `biirabank.com` is hosted at Cloudflare (the registrar). Records that GitHub, Okta or Let's Encrypt must see should be **DNS only** (grey cloud), not proxied, unless a specific reason is documented.

### 2. Active Directory forest: `corp.biirabank.com`

The new forest root is **`corp.biirabank.com`**, NetBIOS name **`CORP`**. This is a delegated subdomain of a public domain the organisation owns, which is Microsoft's recommended pattern. It replaces the split-brain arrangement of the first build, where `ad.biira.online` sat beside a public domain nobody controlled from inside the forest.

Rules that follow from this:

- AD-integrated DNS on DC01 is authoritative for **`corp.biirabank.com` only** and for the reverse zone `50.168.192.in-addr.arpa`. It is **not** authoritative for `biirabank.com`; public names resolve through the forwarder to pfSense and on to public DNS, so `login.biirabank.com` resolves correctly from inside the lab.
- Forwarders on DC01: the pfSense DNS resolver (VLAN 50 gateway, `192.168.50.1`).
- UPN suffix for user accounts: `biirabank.com`, added to the forest, so users sign in as `first.last@biirabank.com` and the UPN matches the Okta and Entra usernames. Do not use `corp.biirabank.com` as a UPN suffix for people.

### 3. Hostnames and addressing (unchanged)

The `<ROLE><NN>` convention stays exactly as documented in the naming standard: `DC01`, `SIEM01`, `ANS01`, `MON01`, `KALI01`, `VAULT01`. Fully qualified: `DC01.corp.biirabank.com`.

DC01 keeps `192.168.50.2` on VLAN 50 (EnterpriseLAN). VLAN plan, subnets and pfSense interface assignments are unchanged; see `docs/01-network-infrastructure.md`.

### 4. Domain controller rebuild: clean install, not demote-and-repromote

DC01 is currently the only domain controller of `ad.biira.online`. Demoting it and re-promoting the same OS instance into a new forest works, but it leaves residue: old DNS zones, SYSVOL remnants, stale certificates, the previous computer identity, and every configuration change made in the first build that nobody remembers. A forest with one DC has nothing to preserve, so:

1. **Back up first.** Take a Proxmox backup of DC01 as it stands (evidence: `dc/dc-NN-pre-rebuild-backup.png`) and export anything worth keeping: the GPO reports, the OU structure export, the user CSV used for the Okta import, the AD Agent installer notes. Keep them under `download/` or `configs/` in the IAM repo for reference.
2. **Fresh Windows Server 2025 VM** on Proxmox (VLAN 50 tag on the virtual NIC; the bridge is VLAN-aware, see `docs/10-proxmox-hypervisor.md`). Hostname `DC01`, static `192.168.50.2/24`, gateway `192.168.50.1`, DNS pointing at itself after promotion (at pfSense before).
3. **Promote** to a new forest: root domain `corp.biirabank.com`, NetBIOS `CORP`, forest and domain functional level Windows Server 2025 (or the highest offered), DNS server and Global Catalog on, DNSSEC off for now.
4. **DSRM password**: generated, stored in the password manager (and in Vault once VAULT01 exists), never in the repo.
5. **Post-promotion checks** (evidence each): `dcdiag /c /v` clean; forward and reverse zones present; `nslookup login.biirabank.com` from DC01 resolves to Okta (proves the forwarder path); time synchronised against pfSense; the pfSense DC rules from `docs/11-domain-controller-firewall.md` re-applied and re-tested.
6. **Then** rebuild the OU structure, tiered admin model and accounts from the IAM lab's Phase 1 and 2 guides, updating those guides as you go rather than after.

Do not join the old Kali, SIEM or monitoring hosts to the new domain until the domain has passed the checks above.

### 5. Email authentication for a domain that sends no mail

Set these at Cloudflare on day one, so nobody can send mail as `@biirabank.com`:

```
TXT  biirabank.com          "v=spf1 -all"
TXT  _dmarc.biirabank.com   "v=DMARC1; p=reject; rua=mailto:nobleantwi3@gmail.com"
MX   biirabank.com          0 .          (null MX, RFC 7505)
```

This is a real control (a phishable domain is a finding), it costs nothing, and it is a good screenshot for the compliance write-up.

### 6. Keep the tenants alive

The Okta Integrator org died of inactivity. For the new one:

- Calendar reminder: sign in to the Okta admin console and the Entra tenant **monthly**.
- Manage the Okta configuration as code with the Terraform Okta provider from the first application onward, and commit it to the IAM repo, so the tenant is rebuildable from files if it is ever lost again.

## Consequences

- `biira.online` is allowed to expire. Both repositories get a one-line note near the top of the README: "Domain retired September 2026; the rebuild uses biirabank.com." Historical screenshots that show `ad.biira.online` and `login.biira.online` stay as they are, labelled as first-build evidence.
- Every runbook that mentions `ad.biira.online` gets a "Rebuild note" box pointing here rather than a silent edit, so the history of the lab stays readable.
- The personal site's case studies (nobleantwi.com/work/) will get a "Version 2" section once the new forest is up; that is handled in the website repository, not here.
- The AI-agent-as-identity scenario (a service account in `corp.biirabank.com`, short-lived Vault credentials, firewall-scoped reach, Wazuh audit) is built on the new forest, not the old one.

## Evidence naming for this work

Per `images/README.md`: `dc/dc-NN-<subject>.png` for the domain controller, `net/` for DNS and forwarder proof, `iam/` in the IAM repo for Okta and Entra custom-domain verification. First capture should be the Cloudflare DNS zone for `biirabank.com` after the records in section 5 exist.
