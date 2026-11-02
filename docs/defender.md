# Defender Control — opt-in module

> Fundray is an enhancement toolkit, **not an operating system**. The Defender
> module is a *switch*, not a recommendation. If you have no other antivirus,
> leave Windows Defender on — that is Fundray's default too.

## Why it exists

Some users pause real-time protection when they:

- already run another antivirus product (two active AVs fight and slow the PC),
- need maximum throughput for one specific heavy task, and understand the risk.

Most tweaking tools flip this silently inside their "one-click boost".
Fundray deliberately does **not**: it is a separate menu item, with warnings,
a typed confirmation, and an undo.

## What it does

**Disable** (`defender.ps1 -Action Disable`):

1. Shows the security warning and requires typing `YES` in uppercase.
2. Sets the documented Group Policy keys:
   - `HKLM\SOFTWARE\Policies\Microsoft\Windows Defender → DisableAntiSpyware = 1`
   - `HKLM\...\Windows Defender\Real-Time Protection → DisableRealtimeMonitoring = 1`
3. Where the cmdlet exists (Windows 8+/10), also runs
   `Set-MpPreference -DisableRealtimeMonitoring $true`.
4. Writes the action to `%ProgramData%\Fundray\logs\defender.log`.

**Enable** (`-Action Enable`): removes those keys and restores protection.

**Status** (`-Action Status`): reports the current state without changing it.

## The honest caveats

- **Tamper Protection**: on recent Windows 10 versions, Windows may block or
  silently revert policy changes. That is Microsoft's safeguard working as
  designed. Use Windows Security → Virus & threat protection settings if you
  need to manage it there.
- **Windows 7**: Defender on 7 is antispyware-era; the policy key applies, but
  Microsoft no longer ships Defender definitions for 7 — use a current AV.
- This module is **never** part of option [1] Full install's optimization
  pass; it only runs when you pick [7] explicitly.

## Undo

`defender.ps1 -Action Enable`, or run `uninstall.bat` — it always re-enables
Defender, even if you forgot.
