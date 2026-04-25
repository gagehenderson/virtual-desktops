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
| `Alt+H` / `Alt+L` | Snap focused window left / right half |
| `Alt+J` / `Alt+K` | Snap focused window down / up |
| `Alt+F` | Fullscreen toggle |
| `Alt+C` | Center focused window on its monitor |
| `Alt+Shift+Q` | Close focused window |
| `Alt+T` | Task View (Win+Tab) |

Snap is implemented via direct `WinMove` against the focused window's
monitor work area.

### Known binding conflicts

If Microsoft 365 / Office Click-to-Run is installed, the `ms-officeapp:`
URI handler is registered and Office Key chord letters shell-exec
`https://go.microsoft.com/fwlink/...` URLs in your default browser. The
Office Key chord scheme maps letters to Office apps (`W = Word`, `H =
Home`, etc.), and a few of these chords can fire even from `Alt+Shift+`
combos depending on the keyboard. Symptom: pressing `Alt+Shift+W` (remove
desktop) or another script binding opens a Microsoft 365 page in your
browser.

Neuter the URI handler with a per-user no-op (covers all Office Key chord
letters at once, doesn't require admin, easy to reverse):

```cmd
reg add "HKCU\Software\Classes\ms-officeapp\Shell\Open\Command" /ve /t REG_SZ /d rundll32 /f
```

Reverse with `reg delete "HKCU\Software\Classes\ms-officeapp\Shell\Open\Command" /f`.

### Misc

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
