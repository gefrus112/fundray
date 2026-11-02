# Fundray

> **Important premise — read this first:** the Fundray **toolkit** for Windows is **not an operating system**.
> It is an enhancement toolkit that runs on top of an existing Windows 7 SP1 / Windows 10 /
> Windows 11 installation. It tunes the system you already have, and every change it makes is
> logged and reversible. It never touches activation, licensing, or system files.

Fundray exists to make older laptops pleasant to use again, without magic tricks and without
risk:

- **Performance** — power plans, whitelist-only service/startup tweaks, temp and Windows Update
  cache cleanup, visual-effect tuning.
- **Windows Terminal** — a separate *Fundray* profile injected into your existing
  `settings.json` (Cascadia Code, dark scheme, sane window defaults). Your configuration is
  never overwritten.
- **Boot & splash** — your own logon background via the documented `OEMBackground` registry
  method, plus an honest BIOS guide for the American Megatrends splash (which is firmware and
  cannot be changed from Windows).
- **Power Panel** — a clean shutdown GUI: Restart, Shut down, Sleep, Sign out, Lock and a
  restore-point button in one dark, easy-to-use window.
- **Defender control (opt-in)** — pause or re-enable Windows Defender real-time protection
  from one switch. Warns, logs, fully reversible, never part of the one-click optimizer.
- **Appearance** — visual-effect tuning plus guides for icon packs and themes. Fundray itself
  never patches or replaces system files.
- **Safety** — a system restore point before every optimization run, full change logging, and a
  one-click restore.

---

---

## What's new in v5 (Fundray Linux — the real thing)

- **Fundray Linux 1.0 "Rebirth"** — the project now ships an actual, bootable
  Linux distribution: official Linux 6.12.115 LTS (configured `tinyconfig` + our
  fragment, `6.12.115-fundray`, ~2.4 MB bzImage), a static BusyBox 1.37.0 userland
  built from source, a 30-line `ctty` getty replacement, and the `fundray` CLI.
  One ~6.3 MB ISO that boots BIOS **and** UEFI, runs live from RAM, and never
  touches a disk. See [os.html](https://gefrus112.github.io/fundray/os.html).
- **Boot-tested, not hand-waved** — the repo ships an automated QEMU test
  (`os/qemu-test.sh`) that boots the ISO over the serial console and verifies
  `uname`, `fundray info`, `fundray clean`, `fundray bench` and a clean reboot
  via `fundray rebirth`. The captured VGA boot screen is on the website.
- **Everything from source** — `os/build.sh` downloads the kernel and BusyBox
  tarballs, verifies the kernel sha256 against kernel.org, compiles both and
  assembles the hybrid ISO with GRUB. The exact kernel config ships in the
  kernel itself (`/proc/config.gz`) and as `os/kernel.config.generated`.
- **The Windows toolkit is unchanged** — same honest scope as before: it tunes
  the Windows you already have and remains a toolkit, not an OS.

## What's new in v4 (website)

- **New "After install" showcase** — [after.html](https://gefrus112.github.io/fundray/after.html)
  walks through what actually changes when you run `install.bat`: the new restart moment, a
  before/after slider of the startup queue, and a readable performance report (example run,
  results vary by machine).
- **New screenshots** — `restart.png`, `before.png`, `after.png`, `report.png` join the gallery.
- **Cooler front page** — aurora hero, animated gradient headline, scroll-reveal sections and a
  rebirth-tour teaser (all pure CSS; `site.js` is progressive enhancement and the site still
  works with JavaScript off).

---

## Project status

| Module | Status |
| --- | --- |
| Performance optimization | Available in source — first public release being packaged |
| Windows Terminal configuration | Available in source — first public release being packaged |
| Boot & splash (logon background) | Available in source — first public release being packaged |
| Power Panel (shutdown GUI) | Available in source — first public release being packaged |
| Defender control (opt-in) | Available in source — first public release being packaged |
| Interface beautification | Available in source — first public release being packaged |
| Windows 11 support | **Supported since v2.1** — installer option [8] + `scripts\win11.ps1` (classic right-click menu, taskbar alignment) |

> Windows 11 is a first-class target: the installer detects the OS version and every module
> adjusts. The full per-module matrix lives on the [Windows 11 page](https://gefrus112.github.io/fundray/windows11.html).

## System requirements

- **OS:** Windows 7 SP1, Windows 10, or Windows 11 (64-bit recommended)
- **Framework:** .NET Framework 4.8 (preinstalled on Windows 10; free download for Windows 7 SP1)
- **PowerShell:** Windows PowerShell 3.0+ (5.1 recommended on Windows 7 — WMF 5.1)
- **Windows Terminal** (optional): only needed for the Terminal configuration module
- **Rights:** Administrator, for restore points, power plans and services

## Installation

1. Download the latest release from
   [GitHub Releases](https://github.com/gefrus112/fundray/releases) — or build it yourself
   (see [Building from source](#building-from-source)).
2. Verify the SHA256 checksum:
   `certutil -hashfile Fundray.exe SHA256`
3. Run `install.bat` (**right-click → Run as administrator**). It detects your Windows version
   (7 SP1 / 10 / 11), shows a module menu —

   ```
   [1] Full install     [2] Performance only   [3] Windows Terminal
   [4] Appearance       [5] Boot & splash      [6] Power Panel
   [7] Defender control [8] Windows 11 tweaks  [9] Files only
   ```

   creates a restore point, copies the toolkit to `%ProgramFiles%\Fundray` and creates Start
   Menu shortcuts (including the Power Panel shutdown GUI).
4. If SmartScreen shows a warning, click **More info → Run anyway**. Antivirus software may
   flag registry/PowerShell tweaking tools generically — the source is fully readable, and
   `SHA256SUMS.txt` in the release covers every shipped file.

Full walkthrough (including SmartScreen and Windows 7 notes): **[docs/install.md](docs/install.md)**.

Curious what your machine looks like *after* the reboot? See the
**[after-install tour](https://gefrus112.github.io/fundray/after.html)** — screenshots of
every change, and the exact undo command for each one.

## Using Fundray

Launch **Fundray** from the Start Menu. The GUI shows one tab per module with individually
checkable tweaks:

1. **Create a restore point first** (`Checkpoint-Computer`). Fundray checks for an existing
   restore point before running optimizations and prompts you if there is none.
2. Tick only the tweaks you want on the **Performance**, **Windows Terminal** and
   **Appearance** tabs and click **Apply selected**.
3. Every executed command is written to the status log and to
   `%ProgramData%\Fundray\logs`.
4. Changed your mind? **One-click restore** replays the change log backwards, and the Terminal
   tab can restore your previous `settings.json` at any time.

## Reverting changes

Three layers of safety, in order of gentlest first:

1. **Fundray one-click restore** — replays the logged changes backwards.
   See **[docs/revert.md](docs/revert.md)**.
2. **Terminal reset** — `scripts\terminal-config.ps1 -Restore` puts your previous
   `settings.json` back.
3. **Windows System Restore** — `rstrui.exe` picks up the restore points Fundray creates.

## Uninstalling

Run `uninstall.bat` (from `%ProgramFiles%\Fundray` or the Add/Remove Programs entry). It
re-enables Windows Defender if the opt-in switch was used, removes the logon background,
offers to undo system tweaks, removes shortcuts and the Add/Remove Programs entry, and deletes
the toolkit folder. It never leaves tweaks behind silently — anything not reverted is listed in
the log.

## Windows Terminal module

The toolkit reads and writes
`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`:

- A timestamped backup (`settings.backup-fundray-*.json`) is made **before** the first write.
- A **separate "Fundray" profile** is added — Cascadia Code, a dark color scheme,
  PowerShell startup, comfortable window size. Your existing profiles are untouched.
- `scripts\terminal-config.ps1 -Restore` removes the Fundray additions and restores your
  previous configuration.

Manual walkthrough: **[docs/terminal.md](docs/terminal.md)**.

## Interface beautification

- **Login background** — documented registry method
  (`OEMBackground` + `C:\Windows\System32\oobe\info\backgrounds\backgroundDefault.jpg`),
  applied by `scripts\appearance.ps1`. Reliable on Windows 7; on Windows 10/11 Microsoft
  restricts this method, and the script says so honestly instead of pretending.
- **Icons & themes** — Fundray does **not** modify system files. It links to a recommended
  icon pack and community theming approaches (e.g. SecureUxTheme + msstyles) in
  `docs/install.md`; third-party tools stay external and optional.

## What Fundray will NOT do

- **No OS claims.** Fundray is not an operating system, does not replace Windows, and does not
  "upgrade" you to another OS.
- **No compatibility miracles.** It makes old machines smoother; it cannot break software
  compatibility limits. Recent Minecraft: Java Edition releases no longer officially support
  Windows 7 — no amount of tuning changes what a vendor stops supporting.
- **No activation/licensing tricks.** Nothing in this repository cracks, bypasses or patches
  Windows activation.
- **No bundled closed-source binaries, no downloads from unknown sources.**

## Building from source

`build.bat` compiles the GUI with the C# compiler that ships with the .NET Framework
(`%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe`), so **no Visual Studio is required**
and it works on Windows 7 SP1. It prints the SHA256 of the produced binary.

If you prefer MSBuild / Visual Studio, open `src\Fundray.csproj` (.NET Framework 4.8, WinForms).

```
git clone https://github.com/gefrus112/fundray.git
cd fundray
build.bat
install.bat   (as administrator)
```

## Project structure

```
fundray/
├── index.html                # Website (GitHub Pages): Home
├── features.html             # Website: feature deep-dive with screenshots
├── docs.html                 # Website: Docs hub (step-by-step, with screenshots)
├── screenshots.html          # Website: gallery (CSS-only lightbox)
├── download.html             # Website: Download (working GitHub links)
├── faq.html                  # Website: FAQ (boot screen, Win7 gaming, Defender...)
├── windows11.html            # Website: Windows 11 support (matrix + Win11 tweaks)
├── styles.css                # Website stylesheet (shared, dark "signal" theme)
├── assets/
│   ├── favicon.svg           # Fundray mark (original signal-ray logo)
│   ├── app.ico               # Windows app icon (generated from the same mark)
│   └── screenshots/          # Generated UI screenshots used by the site
├── README.md
├── LICENSE
├── SHA256SUMS.txt            # Checksums of every shipped script and doc
├── build.bat                 # Compiles src\FundrayMain.cs → build\Fundray.exe
├── install.bat               # FULL installer: OS detect + module menu + shortcuts
├── uninstall.bat             # Clean removal (Defender & splash undo included)
├── optimize.bat              # CLI entry point → scripts\optimize.ps1
├── src/
│   ├── Fundray.csproj        # MSBuild project (net48, WinForms)
│   └── FundrayMain.cs        # C# GUI skeleton
├── scripts/
│   ├── optimize.ps1          # Performance tweaks (restore point, whitelist, logging)
│   ├── terminal-config.ps1   # Terminal settings.json apply / restore
│   ├── appearance.ps1        # Login background (registry method)
│   ├── bootsplash.ps1        # Boot & splash: logon background set/remove/status
│   ├── powerpanel.ps1        # Power Panel shutdown GUI (WinForms, PS 2.0+)
│   ├── defender.ps1          # Opt-in Defender control (status/disable/enable)
│   ├── win11.ps1             # Windows 11 tweaks (classic menu, taskbar align)
│   └── revert.ps1            # Replays the change log backwards
└── docs/
    ├── install.md
    ├── revert.md
    ├── terminal.md
    ├── bootsplash.md         # Logon background + honest BIOS/AMI guide
    ├── defender.md           # What the Defender switch does and does not do
    ├── powerpanel.md         # Power Panel reference
    └── screenshots/          # Placeholder — filled as builds land
```

## Security & compliance

- Restore point **before** every optimization run; Fundray checks for an existing one first.
- All registry modifications are written to a CSV change log with the previous value, so
  `revert.ps1` can undo them exactly.
- Service and startup tweaks are **whitelist-based** — a protected list keeps critical services
  (`WinDefend`, `wuauserv`, `BITS`, `RpcSs`, `DcomLaunch`, …) out of reach.
- No activation cracking, no bundled third-party closed-source tools, no automatic downloads
  from unknown sources.
- SHA256 checksums: printed by `build.bat` and published with every release.

## Documentation

- [docs/install.md](docs/install.md) — installation guide (administrator rights, SmartScreen)
- [docs/revert.md](docs/revert.md) — how to undo all changes
- [docs/terminal.md](docs/terminal.md) — manual Terminal configuration
- [docs/bootsplash.md](docs/bootsplash.md) — logon background + the honest AMI/BIOS guide
- [docs/defender.md](docs/defender.md) — the opt-in Defender switch, explained
- [docs/powerpanel.md](docs/powerpanel.md) — shutdown GUI reference
- [docs/screenshots/](docs/screenshots/) — placeholder directory; screenshots are added as the
  first builds land

## Website

The project website (GitHub Pages) lives in this repository:
<https://gefrus112.github.io/fundray/>

Pages: [Home](https://gefrus112.github.io/fundray/) · [Features](https://gefrus112.github.io/fundray/features.html) · [Docs](https://gefrus112.github.io/fundray/docs.html) · [Screenshots](https://gefrus112.github.io/fundray/screenshots.html) · [Download](https://gefrus112.github.io/fundray/download.html) · [FAQ](https://gefrus112.github.io/fundray/faq.html) · [Windows 11](https://gefrus112.github.io/fundray/windows11.html) (support matrix + Win11 tweaks).

## Roadmap

1. ~~First public release (installer, checksums, screenshots)~~ — done
2. Theme & icon-pack download page — curated, MIT-friendly links only (no bundled binaries)
3. Optional C++ micro-launcher / memory cleaner (kept small, optional and compilable)

## License

[MIT](LICENSE) — use it, fork it, audit it.
