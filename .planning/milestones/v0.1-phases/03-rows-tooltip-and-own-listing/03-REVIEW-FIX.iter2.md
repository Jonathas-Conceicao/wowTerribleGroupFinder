---
phase: 03-rows-tooltip-and-own-listing
fixed_at: 2026-11-11T00:00:00Z
review_path: .planning/phases/03-rows-tooltip-and-own-listing/03-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 3: Code Review Fix Report

**Fixed at:** 2026-11-11
**Source review:** .planning/phases/03-rows-tooltip-and-own-listing/03-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: `W.IconButton` leaks an orphan button when the template loads but is unstyled

**Files modified:** `UI/Widgets.lua`
**Commit:** a0d6483
**Applied fix:** the discarded button is hidden and detached (`SetParent(nil)`) before being replaced by `W.Button`.

### WR-02: Hide button tooltip callbacks assume the parent row always has a listing

**Files modified:** `UI/Table.lua`
**Commit:** 650d3f4
**Applied fix:** added a `RowHidden(b)` helper that is false when the row has no listing; both tooltip callbacks use it.

### WR-03: `Instance:Delist` does not re-check that the player may unlist

**Files modified:** `UI/Table.lua`
**Commit:** 27dcd5e
**Applied fix:** `Delist` returns early when `CanUnlist(self)` is false, after the preview branch and before the `C_LFGList` calls. Logic change: fixed, requires human verification.

Verification: `stylua .` made no changes; the smoke harness reported 0 failed in default, `--gs`, `--fallback` and `--attach` modes.

---

_Fixed: 2026-11-11_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
