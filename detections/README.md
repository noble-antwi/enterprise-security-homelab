# Detection content

Detection and tuning logic for the lab SIEM, kept in version control rather
than only in the appliance, so every change has a reason attached to it.

```
detections/
  wazuh/
    local_rules.xml   deploys to SIEM01:/var/ossec/etc/rules/local_rules.xml
```

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

## Rules currently deployed

| ID | Level | Parent | Effect |
|---|---|---|---|
| 100010 | 0 | 92213 | Silences PowerShell's execution policy probe file, when written by `powershell.exe` and matching the 8.3 random-name shape |

### Gotcha: Sysmon backslashes arrive doubled

`wazuh-logtest` on a real Sysmon FileCreate event decodes the path as:

```
win.eventdata.targetFilename: 'C:\\Windows\\SystemTemp\\__PSScriptPolicyTest_fwonwlyt.yzn.ps1'
```

Those are two literal backslashes, not an escaping artifact of the display. A
pattern written against single backslashes matches nothing, and it fails
silently: the rule simply never fires, with no error anywhere. Where possible,
anchor on the portion of a Windows path that contains no separators at all.
| 100020 | 0 | 92652 | Silences `svc-greenbone` network logons originating from SCAN01 (192.168.20.3) |
| 100021 | 12 | 92652 | Alerts on `svc-greenbone` from any other source |

Every suppression pins at least two independent fields, so the exclusion
cannot be entered by copying a single filename or username.
