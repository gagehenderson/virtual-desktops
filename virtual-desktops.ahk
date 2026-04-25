#Requires AutoHotkey v2.0
#SingleInstance Force
; Force the low-level keyboard hook for every hotkey below. This is what
; lets AHK beat in-process handlers that other apps register for the same
; chord (e.g. Firefox 138+ binds Alt+Shift+H to its AI Chatbot sidebar).
; #UseHook guarantees WH_KEYBOARD_LL handles the chord and swallows
; the event before other apps see it.
#UseHook true
InstallKeybdHook()

; ============================================================
; Virtual Desktop Hotkeys — "loose i3" for Windows
; Uses Ciantic's VirtualDesktopAccessor.dll as the COM wrapper.
;
; Workspaces
;   Alt+1..9 / Alt+0         Jump to desktop N (1..10)
;   Alt+Shift+1..9 / +0      Move focused window to desktop N
;   Alt+N                    New desktop
;   Alt+Shift+W              Remove current desktop (won't remove last)
;
; Windows (on current desktop)
;   Alt+H/J/K/L              Snap focused window left / down / up / right
;   Alt+F                    Fullscreen toggle
;   Alt+C                    Center focused window on its monitor
;   Alt+Shift+Q              Close focused window
;   Alt+T                    Task View (Win+Tab)
; ============================================================

dllPath := A_ScriptDir . "\VirtualDesktopAccessor.dll"
if !FileExist(dllPath) {
    MsgBox "VirtualDesktopAccessor.dll not found at:`n" . dllPath, "virtual-desktops.ahk", "Icon!"
    ExitApp 1
}
hDll := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
if !hDll {
    MsgBox "Failed to load VirtualDesktopAccessor.dll", "virtual-desktops.ahk", "Icon!"
    ExitApp 1
}

GetCurrent() {
    return DllCall("VirtualDesktopAccessor\GetCurrentDesktopNumber", "Int")
}

GetCount() {
    return DllCall("VirtualDesktopAccessor\GetDesktopCount", "Int")
}

IsCloaked(hwnd) {
    cloaked := 0
    DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 14, "Int*", &cloaked, "UInt", 4)
    return cloaked != 0
}

IsOnCurrentDesktop(hwnd) {
    return DllCall("VirtualDesktopAccessor\IsWindowOnCurrentVirtualDesktop", "Ptr", hwnd, "Int")
}

; Enumerate real windows on the current desktop in Z-order (top-most first).
; Filters out shell surfaces, invisible/cloaked/minimized windows, and
; anything without a title. Windows that live on other virtual desktops
; are excluded via Ciantic's IsWindowOnCurrentVirtualDesktop.
GetDesktopWindows() {
    static skipClasses := Map(
        "Progman", 1,
        "WorkerW", 1,
        "Shell_TrayWnd", 1,
        "Shell_SecondaryTrayWnd", 1,
        "Windows.UI.Core.CoreWindow", 1
    )
    result := []
    for hwnd in WinGetList() {
        try {
            style := WinGetStyle(hwnd)
            if !(style & 0x10000000)
                continue
            if (WinGetMinMax(hwnd) = -1)
                continue
            if (skipClasses.Has(WinGetClass(hwnd)))
                continue
            if IsCloaked(hwnd)
                continue
            if !IsOnCurrentDesktop(hwnd)
                continue
            if (WinGetTitle(hwnd) = "")
                continue
            result.Push(hwnd)
        } catch {
            continue
        }
    }
    return result
}

; Windows keeps keyboard focus on the previously focused window after a
; virtual-desktop switch, even when that window is now hidden. Typing then
; lands in the invisible window. After every switch, activate the topmost
; visible window on the new desktop so focus follows the eye. Sleep lets
; the desktop manager update cloak bits first.
FocusTopOnCurrentDesktop() {
    Sleep 50
    list := GetDesktopWindows()
    if (list.Length > 0)
        WinActivate(list[1])
}

SwitchDesktop(n) {
    idx := n - 1
    count := GetCount()
    if (idx < 0 || idx >= count)
        return
    DllCall("VirtualDesktopAccessor\GoToDesktopNumber", "Int", idx)
    FocusTopOnCurrentDesktop()
}

NewDesktop() {
    DllCall("VirtualDesktopAccessor\CreateDesktop", "Int")
}

RemoveCurrent() {
    count := GetCount()
    if (count <= 1)
        return
    cur := GetCurrent()
    fallback := (cur = 0) ? 1 : cur - 1
    DllCall("VirtualDesktopAccessor\RemoveDesktop", "Int", cur, "Int", fallback)
}

MoveWindowToWorkspace(n) {
    idx := n - 1
    count := GetCount()
    if (idx < 0 || idx >= count)
        return
    hwnd := WinExist("A")
    if !hwnd
        return
    DllCall("VirtualDesktopAccessor\MoveWindowToDesktopNumber", "Ptr", hwnd, "Int", idx)
    FocusTopOnCurrentDesktop()
}

KillFocused() {
    hwnd := WinExist("A")
    if hwnd
        WinClose(hwnd)
}

; Direct snap-to-half via WinMove, instead of proxying to Windows' native
; Win+Arrow. The proxy approach loses a race with the still-held physical
; Shift on the trigger chord: when Shift is down, Win+Left/Right is
; interpreted as Win+Shift+Left/Right (move-to-other-monitor) rather
; than snap-half. WinMove avoids the modifier-state race entirely.
SnapWindow(direction) {
    hwnd := WinExist("A")
    if !hwnd
        return
    if (WinGetMinMax(hwnd) = 1)
        WinRestore(hwnd)
    mon := GetMonitorOfWindow(hwnd)
    MonitorGetWorkArea(mon, &mLeft, &mTop, &mRight, &mBottom)
    fullW := mRight - mLeft
    fullH := mBottom - mTop
    halfW := fullW // 2
    halfH := fullH // 2
    switch direction {
        case "Left":  WinMove(mLeft,         mTop,         halfW, fullH, hwnd)
        case "Right": WinMove(mLeft + halfW, mTop,         halfW, fullH, hwnd)
        case "Up":    WinMove(mLeft,         mTop,         fullW, halfH, hwnd)
        case "Down":  WinMove(mLeft,         mTop + halfH, fullW, halfH, hwnd)
    }
}

FullscreenToggle() {
    hwnd := WinExist("A")
    if !hwnd
        return
    if (WinGetMinMax(hwnd) = 1)
        WinRestore(hwnd)
    else
        WinMaximize(hwnd)
}

; Find the monitor containing the window's center point, so centering
; works correctly on multi-monitor setups instead of always using primary.
GetMonitorOfWindow(hwnd) {
    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    cx := wx + ww // 2
    cy := wy + wh // 2
    count := MonitorGetCount()
    loop count {
        MonitorGet(A_Index, &mLeft, &mTop, &mRight, &mBottom)
        if (cx >= mLeft && cx < mRight && cy >= mTop && cy < mBottom)
            return A_Index
    }
    return MonitorGetPrimary()
}

CenterWindow() {
    hwnd := WinExist("A")
    if !hwnd
        return
    if (WinGetMinMax(hwnd) = 1)
        WinRestore(hwnd)
    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    mon := GetMonitorOfWindow(hwnd)
    MonitorGetWorkArea(mon, &mLeft, &mTop, &mRight, &mBottom)
    newX := mLeft + ((mRight - mLeft) - ww) // 2
    newY := mTop + ((mBottom - mTop) - wh) // 2
    WinMove(newX, newY, , , hwnd)
}

; Send Win+Tab via SendEvent. Win11 Task View on 25H2 ignores
; SendInput-injected Win+Tab when the low-level keyboard hook is active
; (filtered by LLKHF_INJECTED). SendEvent uses the older keybd_event
; path that Task View accepts. Releasing held Alt first prevents the
; synthetic Win+Tab from being mistaken for Alt+Tab.
TaskView() {
    prevMode := A_SendMode
    SendMode "Event"
    SendEvent "{LAlt up}{RAlt up}"
    Sleep 50
    SendEvent "#{Tab}"
    SendMode prevMode
}

; Workspace jumps
!1::SwitchDesktop(1)
!2::SwitchDesktop(2)
!3::SwitchDesktop(3)
!4::SwitchDesktop(4)
!5::SwitchDesktop(5)
!6::SwitchDesktop(6)
!7::SwitchDesktop(7)
!8::SwitchDesktop(8)
!9::SwitchDesktop(9)
!0::SwitchDesktop(10)

; Move focused window to workspace
!+1::MoveWindowToWorkspace(1)
!+2::MoveWindowToWorkspace(2)
!+3::MoveWindowToWorkspace(3)
!+4::MoveWindowToWorkspace(4)
!+5::MoveWindowToWorkspace(5)
!+6::MoveWindowToWorkspace(6)
!+7::MoveWindowToWorkspace(7)
!+8::MoveWindowToWorkspace(8)
!+9::MoveWindowToWorkspace(9)
!+0::MoveWindowToWorkspace(10)

; Workspace management
!n::NewDesktop()
!+w::RemoveCurrent()

; Window snap (half-screen)
!h::SnapWindow("Left")
!j::SnapWindow("Down")
!k::SnapWindow("Up")
!l::SnapWindow("Right")

; Window management
!+q::KillFocused()
!f::FullscreenToggle()
!c::CenterWindow()

; Task View. `$` prefix forces explicit WH_KEYBOARD_LL registration as
; defense-in-depth alongside #UseHook, so AHK swallows the chord before
; any in-process app handler (Firefox Tools menu, etc.) can see it.
$!t::TaskView()
