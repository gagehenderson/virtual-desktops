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

AssertPoint(point, x, y, message) {
    AssertEqual(point["x"], x, message . " x")
    AssertEqual(point["y"], y, message . " y")
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

    AssertRect(GridCenteredFullHeightRect(), 4, 0, 4, 2, "centered full-height rect is middle third")

    pixels := GridRectToPixels(Map("col", 9, "row", 1, "colSpan", 3, "rowSpan", 1), 0, 0, 3839, 2159)
    AssertEqual(pixels["x"] + pixels["w"], 3839, "right edge aligns with monitor work area")
    AssertEqual(pixels["y"] + pixels["h"], 2159, "bottom edge aligns with monitor work area")

    AssertPoint(WindowCenterFromRect(100, 200, 801, 601), 500, 500, "window center uses screen rectangle")
}

try {
    RunTests()
    FileAppend "window-grid-tests: ok`n", "*"
    ExitApp 0
} catch as err {
    FileAppend "window-grid-tests: failed - " . err.Message . "`n", "**"
    ExitApp 1
}
