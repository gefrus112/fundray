# Installing Fundray

Fundray is an **enhancement toolkit, not an operating system** — this guide gets
it running on Windows 7 SP1, Windows 10 or Windows 11 in a few minutes.

## 1. Get the files

Two options:

- **Download a release** from
  [github.com/gefrus112/fundray/releases](https://github.com/gefrus112/fundray/releases)
  (each release ships with its SHA256 checksum), **or**
- **Build it yourself** — only .NET Framework 4.8 is required:

  ```bat
  git clone https://github.com/gefrus112/fundray.git
  cd fundray
  build.bat
  ```

  `build.bat` uses the C# compiler that ships with Windows
  (`%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe`), so no Visual Studio
  is needed, even on Windows 7 SP1. The binary lands in `build\Fundray.exe`.

## 2. Verify the checksum (recommended)

Transparency rule: verify before you run anything.

```bat
certutil -hashfile build\Fundray.exe SHA256
```

Compare the output with the checksum published alongside the release. If they
differ, do not run it — open an issue instead.

## 3. Install

1. Right-click **`install.bat`** and choose **Run as administrator**.
   The script self-elevates if you forget.
2. What it does:
   - copies `Fundray.exe` and `scripts\` to `%ProgramFiles%\Fundray`
   - creates a **Start Menu → Fundray** shortcut
   - registers a clean **Add/Remove Programs** entry (removed by `uninstall.bat`)

## 4. SmartScreen & antivirus warnings

- **SmartScreen** ("Windows protected your PC"): Fundray is open source and
  unsigned, so first downloads may trigger it. Click **More info → Run anyway**
  *after* you verified the checksum.
- **Antivirus heuristics**: registry and PowerShell tweaking tools are
  sometimes flagged generically. Nothing in Fundray is obfuscated — you can
  read every command it will run in `scripts\optimize.ps1`,
  `scripts\terminal-config.ps1`, `scripts\appearance.ps1` and
  `scripts\revert.ps1` before you execute anything.

## 5. First launch

1. Start **Fundray** from the Start Menu. If it is not elevated, it offers to
   restart as administrator — accept it (restore points, power plans and
   services need elevation).
2. Go to the **Performance** tab and click **Create restore point**.
3. Tick only the tweaks you want and click **Apply selected optimizations**.
4. Everything the toolkit does is printed in the status log and written to
   `%ProgramData%\Fundray\logs`.

## Notes for Windows 7 SP1

- Install **.NET Framework 4.8** and **WMF 5.1** (PowerShell 5.1) first — both
  are free Microsoft downloads.
- The **login background** module works reliably on Windows 7 (the image must
  be a JPG of 256 KB or less).
- The **Windows Terminal** module needs Windows Terminal installed from the
  Microsoft Store — it is optional.

## Uninstall

Run **`uninstall.bat`** (Start Menu → Fundray → Uninstaller, or from
`%ProgramFiles%\Fundray`). It offers to undo tweaks and restore your Terminal
settings before removing everything. See [revert.md](revert.md) for manual
cleanup paths.

## After the reboot — what changed?

Want the visual tour? The site's [after-install showcase](https://gefrus112.github.io/fundray/after.html)
shows screenshots of every change: the new restart moment, the startup queue before
and after, the Power Panel and the performance report — each with the exact undo
command. Every step here is also covered by `revert.ps1`.
