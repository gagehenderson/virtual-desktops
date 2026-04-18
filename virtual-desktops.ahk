#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Virtual Desktop Hotkeys
; Uses Ciantic's VirtualDesktopAccessor.dll as the COM wrapper.
;
; Alt+1..9 / Alt+0    Jump to desktop N (1..10), index order
; Alt+H               Prev desktop (index order, no wrap)
; Alt+L               Next desktop (index order, no wrap)
; Alt+N               New desktop
; Alt+Shift+W         Remove current desktop (won't remove last)
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

SwitchDesktop(n) {
    idx := n - 1
    count := GetCount()
    if (idx < 0 || idx >= count)
        return
    DllCall("VirtualDesktopAccessor\GoToDesktopNumber", "Int", idx)
}

NextDesktop() {
    cur := GetCurrent()
    count := GetCount()
    if (cur + 1 < count)
        DllCall("VirtualDesktopAccessor\GoToDesktopNumber", "Int", cur + 1)
}

PrevDesktop() {
    cur := GetCurrent()
    if (cur > 0)
        DllCall("VirtualDesktopAccessor\GoToDesktopNumber", "Int", cur - 1)
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

!h::PrevDesktop()
!l::NextDesktop()
!n::NewDesktop()
!+w::RemoveCurrent()
