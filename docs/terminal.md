# Windows Terminal configuration, manually

Fundray configures your **existing** Windows Terminal — it does not replace,
modify or download the app. This page shows what the module changes and how to
do (or undo) it by hand.

## Where settings live

```
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

(Preview/Canary builds use `Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe` /
`Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe`.) The GUI in
**Windows Terminal → Settings → Open JSON file** opens the same file.

## What the Fundray module does

1. **Backup** — copies your current file to
   `settings.backup-fundray-<timestamp>.json` (first run only keeps the
   original; run `-Restore` for a clean slate).
2. **Adds a color scheme** named `Fundray Dark` (dark background, Fundray-blue
   cursor and selection).
3. **Adds a separate profile** named `Fundray`:
   - Cascadia Code, 11 pt (Cascadia ships with Terminal; if missing, Terminal
     falls back automatically)
   - PowerShell startup (`pwsh.exe` if PowerShell 7 is installed, otherwise
     `powershell.exe`)
   - starts in `%USERPROFILE%`, 120×32 window, padded, bar cursor
4. **App defaults** — `defaultProfile`, `initialCols`, `initialRows` and
   `copyOnSelect` are set **only if you have not set them yourself**.

Your existing profiles, schemes and settings are never edited or removed.

## Manual apply (no Fundray GUI)

Edit `settings.json` and add inside the top-level object:

```jsonc
"schemes": [
  {
    "name": "Fundray Dark",
    "background": "#101318", "foreground": "#D8DEE9",
    "cursorColor": "#4CC2FF", "selectionBackground": "#0078D4"
    // ...full palette included when applied by the script
  }
],
"profiles": {
  "list": [
    {
      "name": "Fundray",
      "guid": "{F2A3C91D-8E4B-4C6A-9B7E-2D5A1F0B3E4C}",
      "commandline": "powershell.exe",
      "startingDirectory": "%USERPROFILE%",
      "colorScheme": "Fundray Dark",
      "font": { "face": "Cascadia Code", "size": 11 },
      "padding": "12", "cursorShape": "bar"
    }
  ]
}
```

Or run the script directly:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\terminal-config.ps1 -Apply
```

## Manual restore

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\terminal-config.ps1 -Restore
```

By hand: delete the `Fundray` profile entry, the `Fundray Dark` scheme, and
(re)move `settings.backup-fundray-*.json` over `settings.json`.

## Troubleshooting

- **"Windows Terminal was not found"** — install it from the Microsoft Store,
  start it once so it creates `LocalState\settings.json`, then re-run.
- **Legacy profile schema warning** — very old Terminal versions store
  `profiles` as a plain array. Update Terminal once; Fundray refuses to edit
  the old format rather than risk corrupting it.
- **Settings look unchanged** — Terminal reloads `settings.json` on save; open
  a new tab to see the Fundray profile.
