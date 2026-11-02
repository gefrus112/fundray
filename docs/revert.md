# Reverting changes

Every Fundray change is designed to be reversible. Work through the layers in
this order — start gentle, go deeper only if needed.

## Layer 1 — Fundray one-click restore

The GUI's **One-click restore** button (Performance tab) runs
`scripts\revert.ps1`, which replays Fundray's change log backwards:

```bat
:: newest change log only
powershell -NoProfile -ExecutionPolicy Bypass -File "%ProgramFiles%\Fundray\scripts\revert.ps1"

:: every change log Fundray ever wrote
powershell -NoProfile -ExecutionPolicy Bypass -File "%ProgramFiles%\Fundray\scripts\revert.ps1" -AllFiles

:: also restore your previous Windows Terminal settings
powershell -NoProfile -ExecutionPolicy Bypass -File "%ProgramFiles%\Fundray\scripts\revert.ps1" -Terminal
```

What it undoes, exactly:

| Change type | Undo behaviour |
| --- | --- |
| Registry values | Previous value restored — or the value removed if it did not exist before |
| Services | Previous start mode restored (and service restarted if it was running) |
| Startup entries | Removed Run-key entries recreated |
| Power plan | Previous power scheme re-activated |
| Login background | Original image restored from backup |

Change logs live in `%ProgramData%\Fundray\logs\changes-*.csv` — open them in
any text editor to see exactly what was changed and when. Deleted temporary
files and the Windows Update cache are *not* restorable (they are caches;
Windows rebuilds them).

## Layer 2 — Module-specific resets

- **Windows Terminal:** `terminal-config.ps1 -Restore` (or the GUI button
  *Restore default Terminal settings*) copies the timestamped backup
  `settings.backup-fundray-*.json` back over `settings.json`.
- **Login background:** `appearance.ps1 -RemoveLoginBackground` puts the
  original `backgroundDefault.jpg` back and restores the `OEMBackground`
  registry value.

## Layer 3 — Windows System Restore

Fundray creates a restore point before every optimization run. To roll the
whole machine back to one:

1. Press **Win + R**, type `rstrui.exe`, press Enter.
2. Pick the **Fundray baseline** restore point (or a newer one).
3. Follow the wizard and let Windows restart.

Note: Windows creates at most one restore point per 24 hours by default, so
several Fundray runs on the same day may share one point. The change log in
Layer 1 is independent of this limit.

## Fresh start

`uninstall.bat` offers both Layer 1 and Layer 2 automatically, then removes the
toolkit. Anything you declined to revert stays documented in the logs — Fundray
never leaves unlogged changes behind.
