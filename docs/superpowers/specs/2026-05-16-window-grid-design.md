# Window Grid Hotkey Redesign

## Goal

Redesign the window hotkeys around i3-style vim motions while supporting a large ultrawide monitor. The script should separate focus switching, window movement, and window resizing so directional commands no longer unexpectedly change both position and size.

## Keybindings

- `Alt+H/J/K/L`: focus the nearest real window left/down/up/right.
- `Alt+Shift+H/J/K/L`: move the focused window left/down/up/right on the snap grid while preserving its current grid footprint.
- `Alt+Ctrl+H/J/K/L`: resize the focused window on the snap grid.
  - `Alt+Ctrl+H`: push the left edge left when possible; otherwise push the right edge left.
  - `Alt+Ctrl+L`: push the right edge right when possible; otherwise push the left edge right.
  - `Alt+Ctrl+J`: push the bottom edge down when possible; otherwise push the top edge down.
  - `Alt+Ctrl+K`: push the top edge up when possible; otherwise push the bottom edge up.
- `Alt+1..9`, `Alt+0`: keep switching to desktops 1 through 10.
- `Alt+Shift+1..9`, `Alt+Shift+0`: keep moving the focused window to desktops 1 through 10.
- Remove `Alt+M` for now to force relearning around the new model.

## Layout Model

Use an invisible `12 columns x 2 rows` grid per monitor work area.

This grid supports the target layouts:

- Two full-height halves: each window is `6 columns x 2 rows`.
- Three full-height thirds: each window is `4 columns x 2 rows`.
- Dense eight-window layout: each window is `3 columns x 1 row`.
- Mixed layout such as one full-height left half plus four right-half corner windows: left window is `6 x 2`; right windows are `3 x 1`.

The grid is an implementation detail. The user should experience this as directional focus, move, and resize commands, not as manual grid coordinates.

## Movement Behavior

Movement starts from the focused window's current rectangle, converts it to the nearest grid footprint on that monitor, then shifts that footprint one valid placement in the requested direction.

Movement preserves width and height. For example, a `3 x 1` window in the upper-right half can move down into the lower-right slot without becoming full-width or full-height.

Horizontal movement uses the window's current column span as its jump size. A `6`-column half moves between left and right halves; a `4`-column third moves between left, middle, and right thirds; a `3`-column dense window moves between the four dense columns. Vertical movement uses the current row span, so half-height windows move between top and bottom while full-height windows stay full-height.

If the window is not already aligned to the grid, the first move should snap it to the nearest equivalent grid footprint before moving. If movement would leave the monitor bounds, clamp at the edge.

## Resize Behavior

Resize also starts from the current rectangle and converts it to the nearest grid footprint.

Resize changes the nearest directional edge by one grid column or row. If that edge is already against the monitor boundary, move the opposite edge in the same direction instead. For example, `Alt+Ctrl+L` grows a window to the right when there is room; if the right edge is already at the monitor edge, it shrinks the window from the left. Single-column horizontal resizing is intentional so thirds (`4` columns) and dense quarter-half slots (`3` columns) are both reachable.

The implementation should clamp to the monitor bounds and enforce a minimum footprint of `3 columns x 1 row`, which matches the densest intended layout.

Resize is direct only. There is no resize mode.

## Focus Behavior

Focus switching should use real visible window rectangles on the current virtual desktop, not only windows that were placed by this script.

For a requested direction, choose the visible window whose rectangle is nearest in that direction from the active window. Prefer candidates with axis overlap, then fall back to closest directional distance. This keeps focus switching useful for both snapped and manually positioned windows.

## Removed Behavior

Remove the existing `Alt+H` / `Alt+L` repeated-tap width cycle and the `Alt+M` middle-third shortcut. The new focus/move/resize model replaces those special cases.

## Non-Goals

- No modal resize state.
- No persistent per-window layout database.
- No automatic tiling or layout packing.
- No change to virtual desktop creation/removal, fullscreen, close, center, or Task View unless required by hotkey conflicts.
