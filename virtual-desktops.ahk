#Requires AutoHotkey v2.0
#SingleInstance Force

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
;   Alt+L                    Focus next window
;   Alt+H                    Focus prev window
;   Alt+Shift+Q              Close focused window
;
; Misc
;   Alt+J                    Task View (Win+Tab)
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

; i3's focus-prev/next in a floating WM: Z-order cycle through windows on
; the current desktop. list[1] is the currently active window, so "next"
; activates list[2] (the one behind it) and "prev" activates list[end]
; (the bottom of the stack, which rotates back to front).
FocusNextWindow() {
    list := GetDesktopWindows()
    if (list.Length >= 2)
        WinActivate(list[2])
}

FocusPrevWindow() {
    list := GetDesktopWindows()
    if (list.Length >= 2)
        WinActivate(list[list.Length])
}

TaskView() {
    SendInput("{LAlt up}{RAlt up}")
    Sleep 30
    SendInput("{LWin down}")
    Sleep 30
    SendInput("{Tab}")
    Sleep 30
    SendInput("{LWin up}")
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

; Window focus cycling (current desktop)
!h::FocusPrevWindow()
!l::FocusNextWindow()

; Workspace management
!n::NewDesktop()
!+w::RemoveCurrent()

; Window management
!+q::KillFocused()

; Task View
!j::TaskView()
