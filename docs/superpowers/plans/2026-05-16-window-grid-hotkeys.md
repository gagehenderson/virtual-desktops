# Window Grid Hotkeys Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace width-cycling snap hotkeys with i3-style focus, grid movement, and direct grid resizing.

**Architecture:** Put pure grid math in `window-grid.ahk` so movement and resize rules can be tested without registering hotkeys. Keep desktop and Win32/AHK integration in `virtual-desktops.ahk`. Use a 12-column by 2-row monitor work-area grid.

**Tech Stack:** AutoHotkey v2, Ciantic `VirtualDesktopAccessor.dll`, PowerShell for command execution.

---

### Task 1: Add failing grid behavior tests

**Files:**
- Create: `tests/window-grid-tests.ahk`

- [ ] **Step 1: Write the failing tests**

Create `tests/window-grid-tests.ahk`:

```autohotkey
#Requires AutoHotkey v2.0
#Warn
#Include ..\window-grid.ahk

AssertEqual(actual, expected, message) {
    if (actual != expected)
        throw Error(message . " expected " . expected . " but got " . actual)
}

AssertRect(rect, col, row, colSpan, rowSpan, message) {
    AssertEqual(rect["col"], col, message . " col")
    AssertEqual(rect["row"], row, message . " row")
    AssertEqual(rect["colSpan"], colSpan, message . " colSpan")
    AssertEqual(rect["rowSpan"], rowSpan, message . " rowSpan")
}

RunTests() {
    half := Map("col", 0, "row", 0, "colSpan", 6, "rowSpan", 2)
    AssertRect(GridMoveRect(half, "Right"), 6, 0, 6, 2, "half moves to right half")
    AssertRect(GridMoveRect(GridMoveRect(half, "Right"), "Left"), 0, 0, 6, 2, "half moves back left")

    third := Map("col", 0, "row", 0, "colSpan", 4, "rowSpan", 2)
    AssertRect(GridMoveRect(third, "Right"), 4, 0, 4, 2, "third moves to middle third")
    AssertRect(GridMoveRect(Map("col", 4, "row", 0, "colSpan", 4, "rowSpan", 2), "Right"), 8, 0, 4, 2, "third moves to right third")

    dense := Map("col", 6, "row", 0, "colSpan", 3, "rowSpan", 1)
    AssertRect(GridMoveRect(dense, "Right"), 9, 0, 3, 1, "dense window moves across right half")
    AssertRect(GridMoveRect(dense, "Down"), 6, 1, 3, 1, "dense window moves to lower row")

    leftHalf := Map("col", 0, "row", 0, "colSpan", 6, "rowSpan", 2)
    AssertRect(GridResizeRect(leftHalf, "Left"), 0, 0, 5, 2, "left boundary resize shrinks from right")
    AssertRect(GridResizeRect(leftHalf, "Right"), 0, 0, 7, 2, "right resize expands right edge")

    rightDense := Map("col", 9, "row", 1, "colSpan", 3, "rowSpan", 1)
    AssertRect(GridResizeRect(rightDense, "Right"), 9, 1, 3, 1, "minimum width prevents right-edge shrink below three columns")
    AssertRect(GridResizeRect(rightDense, "Up"), 9, 0, 3, 2, "up resize expands to full height when possible")

    fromPixels := GridRectFromPixels(0, 0, 3840, 2160, 1280, 0, 1280, 2160)
    AssertRect(fromPixels, 4, 0, 4, 2, "pixel conversion recognizes middle third")

    pixels := GridRectToPixels(Map("col", 9, "row", 1, "colSpan", 3, "rowSpan", 1), 0, 0, 3839, 2159)
    AssertEqual(pixels["x"] + pixels["w"], 3839, "right edge aligns with monitor work area")
    AssertEqual(pixels["y"] + pixels["h"], 2159, "bottom edge aligns with monitor work area")
}

RunTests()
ExitApp 0
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tests/window-grid-tests.ahk
```

Expected: failure because `window-grid.ahk` does not exist yet.

### Task 2: Implement pure grid helpers

**Files:**
- Create: `window-grid.ahk`
- Test: `tests/window-grid-tests.ahk`

- [ ] **Step 1: Implement the grid helper functions**

Create `window-grid.ahk` with:

```autohotkey
#Requires AutoHotkey v2.0

global GridColumns := 12
global GridRows := 2
global GridMinColumns := 3
global GridMinRows := 1

GridClamp(value, minValue, maxValue) {
    if (value < minValue)
        return minValue
    if (value > maxValue)
        return maxValue
    return value
}

GridNormalizeRect(rect, columns := 12, rows := 2, minColumns := 3, minRows := 1) {
    colSpan := GridClamp(rect["colSpan"], minColumns, columns)
    rowSpan := GridClamp(rect["rowSpan"], minRows, rows)
    col := GridClamp(rect["col"], 0, columns - colSpan)
    row := GridClamp(rect["row"], 0, rows - rowSpan)
    return Map("col", col, "row", row, "colSpan", colSpan, "rowSpan", rowSpan)
}

GridMoveRect(rect, direction, columns := 12, rows := 2) {
    rect := GridNormalizeRect(rect, columns, rows)
    col := rect["col"], row := rect["row"], colSpan := rect["colSpan"], rowSpan := rect["rowSpan"]
    switch direction {
        case "Left":
            col := Max(0, col - colSpan)
        case "Right":
            col := Min(columns - colSpan, col + colSpan)
        case "Up":
            row := Max(0, row - rowSpan)
        case "Down":
            row := Min(rows - rowSpan, row + rowSpan)
    }
    return GridNormalizeRect(Map("col", col, "row", row, "colSpan", colSpan, "rowSpan", rowSpan), columns, rows)
}

GridResizeRect(rect, direction, columns := 12, rows := 2, minColumns := 3, minRows := 1) {
    rect := GridNormalizeRect(rect, columns, rows, minColumns, minRows)
    col := rect["col"], row := rect["row"], colSpan := rect["colSpan"], rowSpan := rect["rowSpan"]
    switch direction {
        case "Left":
            if (col > 0) {
                col -= 1
                colSpan += 1
            } else if (colSpan > minColumns) {
                colSpan -= 1
            }
        case "Right":
            if (col + colSpan < columns) {
                colSpan += 1
            } else if (colSpan > minColumns) {
                col += 1
                colSpan -= 1
            }
        case "Up":
            if (row > 0) {
                row -= 1
                rowSpan += 1
            } else if (rowSpan > minRows) {
                rowSpan -= 1
            }
        case "Down":
            if (row + rowSpan < rows) {
                rowSpan += 1
            } else if (rowSpan > minRows) {
                row += 1
                rowSpan -= 1
            }
    }
    return GridNormalizeRect(Map("col", col, "row", row, "colSpan", colSpan, "rowSpan", rowSpan), columns, rows, minColumns, minRows)
}

GridRectFromPixels(mLeft, mTop, mRight, mBottom, wx, wy, ww, wh, columns := 12, rows := 2, minColumns := 3, minRows := 1) {
    cellW := (mRight - mLeft) / columns
    cellH := (mBottom - mTop) / rows
    col := Round((wx - mLeft) / cellW)
    row := Round((wy - mTop) / cellH)
    endCol := Round((wx + ww - mLeft) / cellW)
    endRow := Round((wy + wh - mTop) / cellH)
    return GridNormalizeRect(Map("col", col, "row", row, "colSpan", endCol - col, "rowSpan", endRow - row), columns, rows, minColumns, minRows)
}

GridRectToPixels(rect, mLeft, mTop, mRight, mBottom, columns := 12, rows := 2) {
    rect := GridNormalizeRect(rect, columns, rows)
    cellW := (mRight - mLeft) / columns
    cellH := (mBottom - mTop) / rows
    x := Round(mLeft + rect["col"] * cellW)
    y := Round(mTop + rect["row"] * cellH)
    right := Round(mLeft + (rect["col"] + rect["colSpan"]) * cellW)
    bottom := Round(mTop + (rect["row"] + rect["rowSpan"]) * cellH)
    return Map("x", x, "y", y, "w", right - x, "h", bottom - y)
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run:

```powershell
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tests/window-grid-tests.ahk
```

Expected: exit code `0`.

### Task 3: Wire focus, move, resize, and hotkeys into the main script

**Files:**
- Modify: `virtual-desktops.ahk`
- Test: `tests/window-grid-tests.ahk`

- [ ] **Step 1: Include the grid helper file**

Add this near the top after `InstallKeybdHook()`:

```autohotkey
#Include %A_ScriptDir%\window-grid.ahk
```

- [ ] **Step 2: Replace snap/cycle functions with grid integration and directional focus**

Remove `SnapWindow`, `SnapColumn`, cycle globals, `CycleHorizontalSnap`, and the `Alt+M` hotkey. Add helpers that get the focused window's monitor work area, convert it to grid coordinates, call `GridMoveRect` / `GridResizeRect`, convert back to pixels, and `WinMove` the window. Add `FocusWindow(direction)` using `GetDesktopWindows()` and nearest directional rectangle scoring.

- [ ] **Step 3: Update hotkey bindings**

Use these bindings:

```autohotkey
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
```

- [ ] **Step 4: Validate AHK syntax**

Run:

```powershell
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut /Validate virtual-desktops.ahk
```

Expected: exit code `0`.

### Task 4: Update docs and run final verification

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-05-16-window-grid-design.md` if implementation details require any final wording changes.

- [ ] **Step 1: Update README hotkey table**

Document the new focus/move/resize bindings, the 12x2 grid, and removal of `Alt+M`.

- [ ] **Step 2: Run full verification**

Run:

```powershell
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tests/window-grid-tests.ahk
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut /Validate virtual-desktops.ahk
git diff --check
```

Expected: grid tests exit `0`, validation exits `0`, and `git diff --check` exits `0`.
