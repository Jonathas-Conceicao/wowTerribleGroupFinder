---
phase: 08-region-flags-and-row-icon-tooltips
plan: 02
subsystem: ui
tags: [tooltips, icons, hit-frames, table]
requires: [08-01]
provides: [W.ShowTip, W.HitFrame, W.Propagate, W.SetIcon, W.IconTag, row.tgfIcons, row.tgfHits]
affects: [UI/Widgets.lua, UI/Table.lua]
key-files:
  modified: [UI/Widgets.lua, UI/Table.lua]
decisions:
  - Name-cell icons are textures with propagating hit frames, built once per row
  - An icon that would pass the name cell's right edge is hidden with its hit frame
  - Region.MarkupFor kept (harness uses it), no repo caller left
metrics:
  completed: 2026-11-14
---

# Phase 8 Plan 02: Name-cell icon tooltips Summary

Every icon after the name (region flag, Battle.net friend, friend, recent ally, new player friendly, friends in group, Discord) and the class / leader icon is now a real texture with its own hit frame and hover tooltip, without breaking row hover, click-select or the right-click menu.

## Commits
- 99caa93: Widgets helpers (W.ShowTip factored from W.Tooltip, W.HitFrame, W.Propagate, W.SetIcon, W.IconTag)
- 9d33ed3: Table rework (icons built once in BuildRow, FillRow icon strip, IconTooltip, owner checks in row scripts, HoveredRow, RefreshTooltip and the resetter)
- 9daf08a fix: missing Discord art falls back to the voice tag

## Deviations from Plan
- Row OnLeave returns early only when a shown hit frame is under the mouse (not on any `row:IsMouseOver()`), so moving onto the Whisper / hide buttons still hides the row tooltip as before. [Rule 1]
- `Region.MarkupFor` stays in Region.lua (checker note), unused in the repo.
- Harness: the old "discord" probe was rewritten for the texture structure (name width 130 less icons).

## Harness
All three modes (default, --fallback, --attach) print `SUMMARY: 0 failed`; 34 "icons:" checks (propagation flags, no per-fill frames, per-kind tooltip text, greyed rows, recycle cleanup, edge overflow, OnEnter / OnLeave, refresh keeps an icon tooltip). `stylua --check .` passes. The ScrollBox resetter check ran only as a no-op (the harness has no resetter in these modes); the code path is exercised in game only.

## Deferred in-game checks (milestone end)
- Hover each icon (flag, Battle.net friend, friend, recent ally, new player friendly, friends in group, Discord, leader, class) and read its tooltip
- Hover an icon at the very edge of a row; move icon to row to off the row
- Click-select and right-click menu over each icon; mouse wheel over icons still scrolls; Forever's row highlight shows over icons
- Greyed rows keep their icon tooltips
- Scroll so rows recycle while hovering an icon; a search result update while hovering an icon keeps the icon tooltip
- `SetPropagateMouseMotion` / `SetPropagateMouseClicks` exist on Forever's client frames

## Known Stubs
None.

## Self-Check: PASSED
