# Boot & Splash — the honest guide

> Fundray is an enhancement toolkit, **not an operating system**. This module
> covers everything Windows lets us change about what you see when the machine
> starts — and tells you the truth about what it does not.

## What software can and cannot change

| Screen | Who draws it | Can Fundray change it? |
| --- | --- | --- |
| American Megatrends / POST splash | Motherboard **BIOS firmware** | No — see the BIOS guide below |
| OEM logo (full-screen logo) | Motherboard BIOS firmware | No — BIOS setting may change it |
| Windows boot spinner | Windows | No — requires patching `bootres.dll` (system file). Fundray refuses |
| **Logon (sign-in) background** | Windows | **Yes** — documented registry method, below |

The American Megatrends screen appears **before Windows loads**. It belongs to
your motherboard. No honest Windows program can remove it — tools that claim
to are selling you something else.

## Set your own logon background (the documented way)

Works on Windows 7 SP1 and most Windows 10 installations.

1. Pick a `.jpg` image. On Windows 7 it must be under ~256 KB — resave with
   JPEG quality ~80 if needed.
2. Run the installer (`install.bat` → option **[5] Boot & splash**) or call
   the script directly:

   ```bat
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bootsplash.ps1 -Action Set -ImagePath "C:\Users\you\Pictures\bg.jpg"
   ```

3. Press **Win+L** to see the new sign-in background.

What the script does (all of it logged and reversible):

- Copies your image to `%SystemRoot%\System32\oobe\info\backgrounds\backgroundDefault.jpg`
- Backs up any original image to `fundray-backup-backgroundDefault.jpg`
- Sets `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\Background → OEMBackground = 1`

## Undo

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bootsplash.ps1 -Action Remove
```

or simply run `uninstall.bat` — it always removes the tweak.

## BIOS guide: quieting the AMI splash (legitimately)

1. Restart and press **Del** or **F2** (varies by vendor: some use F10/F12) at power-on.
2. In BIOS setup look for **Boot** → **Quiet Boot**, **Full Screen Logo**,
   **Boot Logo** or **Boot Settings Configuration**.
3. Switch *Full Screen Logo* to **Enabled** (hides the POST text) or
   *Quiet Boot* to **Enabled**.
4. Save with **F10** and exit.

That is the only legitimate way to change what firmware draws — and now you
know why no Windows program can do it for you.

## Why Fundray will not replace the boot animation

The Windows boot spinner lives inside `bootres.dll`, a protected system file.
Replacing it is the classic route to an unbootable PC (and a broken Windows
Resource Protection). Fundray's hard rule: **never patch or replace system
files** — so this is one tweak we deliberately do not ship.
