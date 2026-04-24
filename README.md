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

Snap is implemented via direct `WinMove` against the focused window's
monitor work area. (An earlier version proxied to Windows' native
`Win+Arrow`, but the still-held physical `Shift` from the trigger chord
was leaking through and turning `Win+Left/Right` into `Win+Shift+Left/Right`
= move-to-other-monitor, which on a single monitor silently does nothing.)

### Known binding conflicts

AHK's low-level keyboard hook handles every binding in this script and
beats most in-process handlers (e.g. Firefox's AI Chatbot sidebar). But a
few chords can also fire OS-level shell actions that get dispatched
out-of-process, where AHK can't intercept. Two known offenders:

**Microsoft Office "Office Key" chords.** If Microsoft 365 / Office
Click-to-Run is installed, the `ms-officeapp:` URI handler is registered
and Office Key chord letters shell-exec `https://go.microsoft.com/fwlink/...`
URLs in your default browser. The Office Key chord scheme maps letters
to Office apps: `H = Home (microsoft365.com)`, `W = Word`, `X = Excel`,
`L = LinkedIn`, `O = Outlook`, `T = Teams`, `N = OneNote`, `D = OneDrive`,
`P = PowerPoint`, `Y = Yammer`. Several of these (`H`, `W`, `L`) collide
with this script's bindings.

Symptom: pressing one of the snap or workspace-management hotkeys opens
a Microsoft 365 page or launches an Office app in your browser, even
with the AHK script running and even with Microsoft 365 itself not running.

Neuter the URI handler with a per-user no-op (covers all Office Key chord
letters at once, doesn't require admin, easy to reverse):

```cmd
reg add "HKCU\Software\Classes\ms-officeapp\Shell\Open\Command" /ve /t REG_SZ /d rundll32 /f
```

Reverse with `reg delete "HKCU\Software\Classes\ms-officeapp\Shell\Open\Command" /f`.

**Firefox 138+ AI Chatbot.** Firefox binds `Alt+Shift+H` to open its AI
Chatbot sidebar via an in-process handler. AHK's `#UseHook true` plus
the `$` prefix on each hotkey usually beats Firefox to the chord. If
Firefox still wins on your machine (symptom: pressing `Alt+Shift+H`
opens Firefox's AI sidebar instead of snapping the focused window),
disable the feature in `about:config`: set `browser.ml.chat.enabled` to
`false` and restart Firefox.

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
