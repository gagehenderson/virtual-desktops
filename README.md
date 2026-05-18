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
| `Alt+H` / `Alt+J` / `Alt+K` / `Alt+L` | Focus nearest window left / down / up / right |
| `Alt+Shift+H` / `Alt+Shift+J` / `Alt+Shift+K` / `Alt+Shift+L` | Move focused window left / down / up / right on the snap grid |
| `Alt+Ctrl+H` / `Alt+Ctrl+J` / `Alt+Ctrl+K` / `Alt+Ctrl+L` | Resize focused window left / down / up / right on the snap grid |
| `Alt+M` | Move focused window to the centered full-height third |
| `Alt+F` | Fullscreen toggle |
| `Alt+C` | Center focused window on its monitor |
| `Alt+Shift+Q` | Close focused window |
| `Alt+T` | Task View (Win+Tab) |

Window movement and resizing are implemented via direct `WinMove` against
the focused window's monitor work area.

The snap grid is 12 columns by 2 rows per monitor. It supports full-height
halves, full-height thirds, dense 8-window layouts, and mixed layouts like
one full-height half plus four corner windows on the other half. Movement
preserves the window's current grid footprint: a half-width window moves
between halves, a third-width window moves between thirds, and a dense
quarter-half window moves between dense slots.

Resize changes the requested edge by one grid column or row. If that edge
is already against the monitor boundary, the opposite edge moves in the
same direction instead. There is no resize mode.

Focus switching uses the real visible window rectangles on the current
virtual desktop, so it works with both snapped and manually positioned
windows. When focus changes through `Alt+H/J/K/L`, the mouse pointer moves
to the center of the newly focused window.

### Known binding conflicts

If Microsoft 365 / Office Click-to-Run is installed, the `ms-officeapp:`
URI handler is registered and Office Key chord letters shell-exec
`https://go.microsoft.com/fwlink/...` URLs in your default browser. The
Office Key chord scheme maps letters to Office apps (`W = Word`, `H =
Home`, etc.), and a few of these chords can fire even from `Alt+Shift+`
combos depending on the keyboard. Symptom: pressing `Alt+Shift+W` (remove
desktop), `Alt+Shift+H` (move window left), or another script binding opens
a Microsoft 365 page in your browser.

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
