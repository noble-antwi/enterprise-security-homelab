# Detection content

Detection and tuning logic for the lab SIEM, kept in version control rather
than only in the appliance, so every change has a reason attached to it.

```
detections/
  wazuh/
    local_rules.xml                    deploys to SIEM01:/var/ossec/etc/rules/local_rules.xml
    stock_copilot_identity_rules.xml   deploys to SIEM01:/var/ossec/etc/rules/stock_copilot_identity_rules.xml
```

`stock_copilot_identity_rules.xml` watches the identity audit log of Stock
Copilot on APP01 (sign-ins, refused tokens, SCIM, key rotation,
break-glass). Its Sigma rules, ATT&CK map, runbooks and the agent install
steps live with the app, in the stock-copilot repo under
`docs/identity/detections/`, because they change when the app's events do.
Before any change here is deployed, it is tested off SIEM01 against the
app's own events:

```bash
.venv/bin/python scripts/identity-wazuh-logtest.py <this repo>/detections/wazuh/stock_copilot_identity_rules.xml --lab
```

(run in the stock-copilot repo; it starts a throwaway `wazuh-manager:4.14.7`
container with no network, checks the file, and replays sample and real
lab events through `wazuh-logtest`).

## Why tuning is part of the build

A rule that fires constantly on benign activity is worse than no rule. Wazuh
rule 92213 ("Executable file dropped in folder commonly used by malware")
ships at **level 15**, the top severity, with MITRE T1105 attached. It is
tripped every few minutes on every Windows host by PowerShell writing its own
execution policy probe file into `%TEMP%`. An analyst who sees that alert
forty times a day stops reading level 15 alerts, which is exactly the outcome
the rule was written to prevent.

The same happened in reverse during the first credentialed vulnerability
scan: one scan of one workstation produced **2,051** level 6 alerts from rule
92652, because the scanner authenticates to every service it probes.

Both are tuned in `wazuh/local_rules.xml`, and both keep a loud path open for
the same activity arriving from somewhere unexpected.

## Deploying a change

Run on SIEM01.

1. Back up the current file, then copy the new one into place and match the
   ownership and mode of the file that was already there.

   ```bash
   sudo cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.bak
   ```

   A **new** rules file (the first `stock_copilot_identity_rules.xml`) has no
   file to match, so set it the way Wazuh sets its own rules: owned by
   `wazuh:wazuh`, mode 660. Anything in `etc/rules/` ending in `.xml` is
   loaded; no change to `ossec.conf` is needed.

   ```bash
   sudo install -o wazuh -g wazuh -m 660 stock_copilot_identity_rules.xml /var/ossec/etc/rules/
   ```

2. Validate the ruleset **before** restarting. A malformed `local_rules.xml`
   will stop `wazuh-manager` from starting at all, which takes the whole SIEM
   offline rather than just breaking one rule.

   ```bash
   sudo /var/ossec/bin/wazuh-analysisd -t
   ```

3. Restart and confirm it came back.

   ```bash
   sudo systemctl restart wazuh-manager && sudo systemctl status wazuh-manager --no-pager
   ```

4. Test the logic against a real event with `wazuh-logtest`. Paste a raw
   event, and it reports which decoder parsed it and which rule matched.

   ```bash
   sudo /var/ossec/bin/wazuh-logtest
   ```

   A suppression is working when logtest reports the new rule id at level 0.
   If it still reports the parent rule, the field match did not hit: check the
   exact field names in the alert JSON, because they are case sensitive.

## Rule numbering

Custom rules must be 100000 or above. Blocks in use:

| Range | Purpose |
|---|---|
| 100010-100019 | Sysmon noise suppression |
| 100020-100029 | Authorised scanner activity |
| 100400-100499 | Stock Copilot identity audit log (APP01) |

## Rules currently deployed

| ID | Level | Parent | Effect |
|---|---|---|---|
| 100010 | 0 | 92213 | Silences PowerShell's execution policy probe file, when written by `powershell.exe` and matching the 8.3 random-name shape |
| 100020 | 0 | 92652 | Silences `svc-greenbone` network logons originating from SCAN01 (192.168.20.3) |
| 100021 | 12 | 92652 | Alerts on `svc-greenbone` from any other source |
| 100022 | 0 | 60137 | Silences `svc-greenbone` network logoffs (logon type 3). Misuse of the account is caught at logon by 100021 |

Every suppression pins at least two independent fields, so the exclusion
cannot be entered by copying a single filename or username.

### Stock Copilot identity (100400-100499): written and tested, deploy pending

Tested with `wazuh-logtest` 4.14.7: 59 of 59 sample events reach their rule,
and a replay of the lab's real audit log (676 events from the Stage 10
scenarios, Stage 12 rotation drills and Stage 13 attack probe) lands every
refusal on its rule. Waiting on the Wazuh agent on APP01.

| ID | Level | Parent | MITRE | Effect |
|---|---|---|---|---|
| 100400 | 0 | json decoder | - | Claims every event with `service.name` stock-copilot and `service.type` identity; silent on its own |
| 100401 | 3 | 100400 | - | `user.name` signed in through `idp.key` |
| 100402 | 5 | 100400 | - | sign-in refused for `user.name`: `detail.reason` |
| 100407 | 5 | 100402 | - | a credential was refused for `user.name`: `detail.reason` |
| 100403 | 10 | 100407 | T1110 | repeated refused credentials from `source.tailnet_node` (password guessing?) (5 within 120 s, same `source.tailnet_node`) |
| 100404 | 10 | 100400 | T1078.003 | the break-glass owner login was used |
| 100405 | 12 | 100400 | T1098 | the break-glass owner was reset on APP01 |
| 100406 | 7 | 100400 | T1621 | a step-up to a sensitive area failed for `user.name` |
| 100410 | 6 | 100400 | - | token refused (`idp.key`): `detail.reason` |
| 100411 | 12 | 100410 | T1606 | forged token, unsigned or algorithm confusion: `detail.reason` |
| 100412 | 12 | 100410 | T1606.002 | forged SAML assertion (unsigned, wrapped or tampered): `detail.reason` |
| 100413 | 10 | 100410 | T1550.001 | replayed token, nonce or login state: `detail.reason` |
| 100414 | 10 | 100410 | T1136 | SCIM call without a valid credential: `detail.reason` |
| 100415 | 10 | 100410 | T1110 | a burst of refused tokens from `source.tailnet_node` (10 within 120 s, same `source.tailnet_node`) |
| 100416 | 8 | 100410 | T1550.001 | a revoked API token was used again |
| 100420 | 8 | 100400 | T1550.001 | API token used beyond its scope (`detail.client`): `detail.reason` |
| 100421 | 10 | 100420 | T1550.001 | client `detail.client` keeps reaching beyond its scopes (5 within 300 s, same `detail.client`) |
| 100430 | 8 | 100400 | T1185 | cross-site request refused on `detail.path` for `user.name` |
| 100440 | 5 | 100400 | - | `user.name` refused `detail.path`: `detail.reason` |
| 100441 | 10 | 100440 | T1083 | `user.name` keeps reaching for what was not given (10 within 300 s, same `user.name`) |
| 100442 | 6 | 100440 | - | a tailnet device asked for data without signing in (`source.tailnet_node`) |
| 100450 | 8 | 100400 | T1566.002 | open-redirect attempt to `detail.asked` |
| 100460 | 12 | 100400 | T1098 | refused attempt to link an identity: `detail.reason` |
| 100461 | 8 | 100400 | T1098 | `user.name` now holds lab-admin |
| 100463 | 8 | 100400 | T1098 | group `detail.mapping` now maps to lab-admin |
| 100462 | 3 | 100400 | - | the directory deactivated `user.name` |
| 100470 | 12 | 100400 | T1556 | signing keys changed at `idp.key` outside any declared rotation |
| 100471 | 3 | 100400 | - | scheduled rotation, `detail.drill`: `detail.step` |
| 100480 | 3 | 100400 | - | access review signed off |

Two lessons from building it:
- **Count credentials, not refusals.** The first password-guessing rule
  counted every refused sign-in and raised seven false alerts on the lab's
  own traffic, all refusals by policy (a person not provisioned, a group
  with no mapping). 100403 now counts only 100407, the credential reasons,
  and counts per tailnet device: a refused passkey names nobody, and a
  guesser can change the email every try.
- **A word is not a meaning.** The forged-SAML rule first matched any
  reason containing "assertion", which would have paged "assertion
  expired" (clock skew) as forgery at level 12. It now matches only the
  signature failures, and a test in the app repo checks every rule against
  the app's real refusal wording.

### Gotcha: Sysmon backslashes arrive doubled

`wazuh-logtest` on a real Sysmon FileCreate event decodes the path as:

```
win.eventdata.targetFilename: 'C:\\Windows\\SystemTemp\\__PSScriptPolicyTest_fwonwlyt.yzn.ps1'
```

Those are two literal backslashes, not an escaping artifact of the display. A
pattern written against single backslashes matches nothing, and it fails
silently: the rule simply never fires, with no error anywhere. Where possible,
anchor on the portion of a Windows path that contains no separators at all.
