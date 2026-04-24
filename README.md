# virtual-desktops

i3-style direct-jump hotkeys for Windows virtual desktops.

Windows has no native "jump to desktop N" shortcut, only cycle. This script adds it.

## Hotkeys

| Key | Action |
|-----|--------|
| `Alt+1..9`, `Alt+0` | Jump to desktop 1..10 (index order) |
| `Alt+H` | Prev desktop (no wrap) |
| `Alt+L` | Next desktop (no wrap) |
| `Alt+N` | New desktop |
| `Alt+Shift+W` | Remove current desktop (keeps at least 1) |
| `Alt+J` | Task View (Win+Tab) |

Navigation is by index, not recency.

After every switch, the topmost visible window on the new desktop is
activated. Windows does not move keyboard focus when you change virtual
desktops, so without this your typing would land in the previously focused
(now hidden) window.

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
