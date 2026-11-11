---
phase: 03-rows-tooltip-and-own-listing
fixed_at: 2026-11-11T00:00:00Z
review_path: .planning/phases/03-rows-tooltip-and-own-listing/03-REVIEW.md
iteration: 2
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
---

# Phase 3: Code Review Fix Report

**Fixed at:** 2026-11-11
**Source review:** .planning/phases/03-rows-tooltip-and-own-listing/03-REVIEW.md
**Iteration:** 2

**Summary:**
- Findings in scope: 1
- Fixed: 1
- Skipped: 0

Iteration 1 (still in place): WR-01 orphan icon button detached (a0d6483), WR-02 hide button tooltip guarded against rows without a listing (650d3f4), WR-03 `Delist` re-checks `CanUnlist` (27dcd5e).

## Fixed Issues

### WR-01: `BossNames` queries the real API with a preview listing's id

**Files modified:** `UI/Table.lua`
**Commit:** f71ac6b
**Applied fix:** `BossNames(l, inst)` returns nil for your own row and when the instance's source is in preview; `StockTooltip` and `ShowTooltip` pass `inst` through. Logic change: fixed, requires human verification.

Verification: `stylua .` made no changes; the smoke harness reported 0 failed in default, `--gs`, `--fallback` and `--attach` modes. The harness's `tip-solo` probe used preview data and expected the boss lookup, so it now switches the source to non-preview for the boss checks and also asserts that preview data makes no encounter call (harness edit is outside the repo).

## Not in scope (Info, not fixed)

IN-01 (probe the icon template once), IN-02 (rename shadowing `view`), IN-03 (move the click sound in `Delist`).

---

_Fixed: 2026-11-11_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
