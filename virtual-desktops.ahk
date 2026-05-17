#Requires AutoHotkey v2.0
#SingleInstance Force
; Force the low-level keyboard hook for every hotkey below. This is what
; lets AHK beat in-process handlers that other apps register for the same
; chord (e.g. Firefox 138+ binds Alt+Shift+H to its AI Chatbot sidebar).
; #UseHook guarantees WH_KEYBOARD_LL handles the chord and swallows
; the event before other apps see it.
#UseHook true
#Include window-grid.ahk
InstallKeybdHook()
CoordMode "Mouse", "Screen"

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
;   Alt+H/J/K/L              Focus nearest window left/down/up/right
;   Alt+Shift+H/J/K/L        Move focused window on a 12x2 grid
;   Alt+Ctrl+H/J/K/L         Resize focused window on a 12x2 grid
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

EnsureRestored(hwnd) {
    if (WinGetMinMax(hwnd) = 1)
        WinRestore(hwnd)
}

GetGridContext(hwnd) {
    WinGetPos(&wx, &wy, &ww, &wh, hwnd)
    mon := GetMonitorOfWindow(hwnd)
    MonitorGetWorkArea(mon, &mLeft, &mTop, &mRight, &mBottom)
    rect := GridRectFromPixels(mLeft, mTop, mRight, mBottom, wx, wy, ww, wh)
    return Map(
        "rect", rect,
        "mLeft", mLeft,
        "mTop", mTop,
        "mRight", mRight,
        "mBottom", mBottom
    )
}

ApplyGridRect(hwnd, context, rect) {
    pixels := GridRectToPixels(rect, context["mLeft"], context["mTop"], context["mRight"], context["mBottom"])
    WinMove(pixels["x"], pixels["y"], pixels["w"], pixels["h"], hwnd)
}

MoveWindowOnGrid(direction) {
    hwnd := WinExist("A")
    if !hwnd
        return
    EnsureRestored(hwnd)
    context := GetGridContext(hwnd)
    rect := GridMoveRect(context["rect"], direction)
    ApplyGridRect(hwnd, context, rect)
}

ResizeWindowOnGrid(direction) {
    hwnd := WinExist("A")
    if !hwnd
        return
    EnsureRestored(hwnd)
    context := GetGridContext(hwnd)
    rect := GridResizeRect(context["rect"], direction)
    ApplyGridRect(hwnd, context, rect)
}

GetWindowRectMap(hwnd) {
    WinGetPos(&x, &y, &w, &h, hwnd)
    return Map(
        "left", x,
        "top", y,
        "right", x + w,
        "bottom", y + h,
        "cx", x + w / 2,
        "cy", y + h / 2
    )
}

MoveMouseToWindowCenter(hwnd) {
    try {
        WinGetPos(&x, &y, &w, &h, hwnd)
        point := WindowCenterFromRect(x, y, w, h)
        MouseMove(point["x"], point["y"], 0)
    }
}

DirectionalFocusScore(active, candidate, direction) {
    switch direction {
        case "Left":
            if (candidate["cx"] >= active["cx"])
                return ""
            overlap := Min(active["bottom"], candidate["bottom"]) - Max(active["top"], candidate["top"])
            gap := Max(0, active["left"] - candidate["right"])
            perpendicular := Abs(active["cy"] - candidate["cy"])
        case "Right":
            if (candidate["cx"] <= active["cx"])
                return ""
            overlap := Min(active["bottom"], candidate["bottom"]) - Max(active["top"], candidate["top"])
            gap := Max(0, candidate["left"] - active["right"])
            perpendicular := Abs(active["cy"] - candidate["cy"])
        case "Up":
            if (candidate["cy"] >= active["cy"])
                return ""
            overlap := Min(active["right"], candidate["right"]) - Max(active["left"], candidate["left"])
            gap := Max(0, active["top"] - candidate["bottom"])
            perpendicular := Abs(active["cx"] - candidate["cx"])
        case "Down":
            if (candidate["cy"] <= active["cy"])
                return ""
            overlap := Min(active["right"], candidate["right"]) - Max(active["left"], candidate["left"])
            gap := Max(0, candidate["top"] - active["bottom"])
            perpendicular := Abs(active["cx"] - candidate["cx"])
        default:
            return ""
    }
    overlapPenalty := (overlap > 0) ? 0 : 1
    return overlapPenalty * 1000000000 + gap * 100000 + perpendicular
}

FocusWindow(direction) {
    activeHwnd := WinExist("A")
    if !activeHwnd
        return
    try {
        activeRect := GetWindowRectMap(activeHwnd)
    } catch {
        return
    }

    bestHwnd := 0
    bestScore := ""
    for hwnd in GetDesktopWindows() {
        if (hwnd = activeHwnd)
            continue
        try {
            candidateRect := GetWindowRectMap(hwnd)
            score := DirectionalFocusScore(activeRect, candidateRect, direction)
        } catch {
            continue
        }
        if (score = "")
            continue
        if (!bestHwnd || score < bestScore) {
            bestHwnd := hwnd
            bestScore := score
        }
    }
    if bestHwnd {
        WinActivate(bestHwnd)
        MoveMouseToWindowCenter(bestHwnd)
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

; i3-style window navigation and arrangement.
!h::FocusWindow("Left")
!j::FocusWindow("Down")
!k::FocusWindow("Up")
!l::FocusWindow("Right")

!+h::MoveWindowOnGrid("Left")
!+j::MoveWindowOnGrid("Down")
!+k::MoveWindowOnGrid("Up")
!+l::MoveWindowOnGrid("Right")

!^h::ResizeWindowOnGrid("Left")
!^j::ResizeWindowOnGrid("Down")
!^k::ResizeWindowOnGrid("Up")
!^l::ResizeWindowOnGrid("Right")

; Window management
!+q::KillFocused()
!f::FullscreenToggle()
!c::CenterWindow()

; Task View. `$` prefix forces explicit WH_KEYBOARD_LL registration as
; defense-in-depth alongside #UseHook, so AHK swallows the chord before
; any in-process app handler (Firefox Tools menu, etc.) can see it.
$!t::TaskView()
