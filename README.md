# virtual-desktops

"Loose i3" hotkeys for Windows virtual desktops: i3-style keybinds for
workspace navigation, window movement, and window focus, without forcing
you into a tiling layout. Windows stay floating and resizable, you just get
the keyboard ergonomics.

Windows has no native "jump to desktop N" shortcut, only cycle. This script
fixes that and adds the rest of the i3 muscle memory that makes sense for
a floating window manager.

## Hotkeys

### Workspaces

| Key | Action |
|-----|--------|
| `Alt+1..9`, `Alt+0` | Jump to desktop 1..10 |
| `Alt+Shift+1..9`, `Alt+Shift+0` | Move focused window to desktop 1..10 |
| `Alt+N` | New desktop |
| `Alt+Shift+W` | Remove current desktop (keeps at least 1) |

### Windows (on current desktop)

| Key | Action |
|-----|--------|
| `Alt+L` | Focus next window (Z-order cycle) |
| `Alt+H` | Focus prev window |
| `Alt+Shift+H` / `Alt+Shift+L` | Snap focused window left / right half |
| `Alt+Shift+J` / `Alt+Shift+K` | Snap focused window down / up |
| `Alt+F` | Fullscreen toggle |
| `Alt+C` | Center focused window on its monitor |
| `Alt+Shift+Q` | Close focused window |

Snap is a proxy to Windows' native `Win+Arrow`, so it inherits snap-assist,
multi-monitor awareness, and snap-state cycling (half then quarter).

### Known binding conflicts

Two different system features compete for `Alt+Shift+H` on a typical
Windows 11 install. AHK's low-level keyboard hook handles the binding
itself, but the chord can also trigger an OS shell action that AHK
can't suppress because the dispatch happens out-of-process.

**Microsoft Office "Office Key" chord.** If you have Microsoft 365 /
Office Click-to-Run installed, the `ms-officeapp:` URI handler is
registered and `Alt+Shift+H` (interpreted as `Office Key + H = Home`)
shell-execs `https://go.microsoft.com/fwlink/?linkid=2044481&from=OfficeKey`
in your default browser. Symptom: pressing the chord opens the
Microsoft 365 home page in your browser even with the AHK script running
and even with Microsoft 365 itself not running.

Neuter the URI handler with a per-user no-op:

```cmd
reg add "HKCU\Software\Classes\ms-officeapp\Shell\Open\Command" /ve /t REG_SZ /d rundll32 /f
```

Reverse with `reg delete "HKCU\Software\Classes\ms-officeapp\Shell\Open\Command" /f`.

**Firefox 138+ AI Chatbot.** Firefox binds `Alt+Shift+H` to open its AI
Chatbot sidebar via an in-process handler. AHK's `#UseHook true` plus
the `$` prefix on each hotkey forces a low-level keyboard hook that
beats Firefox in most setups. If Firefox still wins, disable the
feature in `about:config`: set `browser.ml.chat.enabled` to `false`.

### Misc

| Key | Action |
|-----|--------|
| `Alt+J` | Task View (Win+Tab) |

Workspace navigation is by index, not recency.

After every desktop switch (or after moving a window to another desktop),
the topmost visible window on the current desktop is activated. Windows
does not move keyboard focus when you change virtual desktops, so without
this your typing would land in the previously focused (now hidden) window.

## Install

1. Install AutoHotkey v2: `winget install AutoHotkey.AutoHotkey` (or https://www.autohotkey.com/)
2. Clone this repo anywhere (it matters that the DLL sits next to the script).
3. Double-click `virtual-desktops.ahk` to run.
4. To autostart on login: Win+R, run `shell:startup`, drop a shortcut to `virtual-desktops.ahk` into that folder.

## How it works

`VirtualDesktopAccessor.dll` (by [Ciantic](https://github.com/Ciantic/VirtualDesktopAccessor), MIT licensed) wraps the undocumented Windows virtual desktop COM API and exposes simple functions. The `.ahk` script is a thin hotkey layer over those functions.

When Windows updates break the DLL (rare, usually on major build upgrades), grab the newest release from [Ciantic's repo](https://github.com/Ciantic/VirtualDesktopAccessor/releases) and replace the file.

## Tested on

Windows 11 25H2, Build 26200.8246.

## License

MIT. See [`LICENSE`](LICENSE).

The bundled `VirtualDesktopAccessor.dll` is a separate MIT-licensed work by
Jari Pennanen (Ciantic). See [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).
