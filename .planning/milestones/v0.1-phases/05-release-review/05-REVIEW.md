---
phase: 05-release-review
reviewed: 2026-11-11
depth: standard
scope: git diff 1cb31bb..HEAD (Core.lua, Messages.lua, UI/InPlace.lua, UI/Table.lua, UI/Widgets.lua, CLAUDE.md, CHANGELOG.md)
status: clean
findings:
  critical: 0
  warning: 0
  info: 2
---

# Phase 5: Code Review

**Status:** clean (0 critical, 0 warning, 2 info). No fix pass needed (default fix scope is critical + warning).

## Checked

- Key-button wrap: `wrapped` flag, at most one wrap
- Example line: `Sample()` picks the first preview listing of the right kind (`l.solo`); nil handled by `M.Format`
- Paste cursor: restored only when the text before the cursor is ASCII; `\r\n` collapse counted
- `searching()` / `failed()` false while previewing; searching branch clears status and `shownIDs`
- `VoiceLabels` cached; `HoveredRow` after the visibility guard
- `row.item` removed; remaining `.item` reads are on section-header frames (set in `FillHeader`)
- `W.Line` has no callers; `scrollView` rename complete; hide hint wording; no planning IDs in shipped code
- CHANGELOG v0.1.0: +19 lines, all above `## Unreleased`; every claim matches the code; gear score not advertised
- CLAUDE.md: new lines match the code; no in-milestone bug history

## Info

### IN-01: Key-button wrap can leave the second row over `BOX_WIDTH`

**File:** `Messages.lua:453-457`
**Issue:** If a width overflow in row 1 triggers the single wrap early, the `i == 5` wrap is suppressed and row 2 could hold more than 3 buttons. Not reachable with the current key labels.
**Fix:** Optional; keep wrap-once (no third row over Auto-send is the priority) or clamp row 2.

### IN-02: Paste keeps the cursor only for ASCII text

**File:** `Messages.lua:395-406`
**Issue:** Intended ASCII-only restore; the comment does not say why.
**Fix:** One-line comment: `GetCursorPosition` counts characters, `sub` counts bytes.

---

_Reviewer: gsd-code-reviewer (standard depth)_
