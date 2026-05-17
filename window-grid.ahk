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
    col := rect["col"]
    row := rect["row"]
    colSpan := rect["colSpan"]
    rowSpan := rect["rowSpan"]

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
    col := rect["col"]
    row := rect["row"]
    colSpan := rect["colSpan"]
    rowSpan := rect["rowSpan"]

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

WindowCenterFromRect(x, y, w, h) {
    return Map("x", x + w // 2, "y", y + h // 2)
}
