---
phase: 01-gear-score-off-and-release-plumbing
fixed_at: 2026-11-11T16:45:00Z
review_path: .planning/phases/01-gear-score-off-and-release-plumbing/01-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 3
skipped: 1
status: partial
---

# Phase 1: Code Review Fix Report

**Fixed at:** 2026-11-11T16:45:00Z
**Source review:** .planning/phases/01-gear-score-off-and-release-plumbing/01-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (warnings only; scope `critical_warning`, no critical findings)
- Fixed: 3
- Skipped: 1 (author decision)

Verification for every fix:
- `stylua .` was run, and `stylua --check .` is clean.
- The smoke harness passes in both modes (`SUMMARY: 0 failed` off and `--gs`).
- The harness got new assertions for WR-02, WR-03 and WR-04. They fail on the pre-fix code (5 failures) and pass on the fixed code.

## Fixed Issues

### WR-02: The switch is not fully reversible (default preset and saved text lose `{gs}` for good)

**Files modified:** `Core.lua`, `Messages.lua`, `.planning/research/GEARSCORE.md`
**Commit:** 7721376
**Applied fix:** This follows the author's decision to keep the D-10 migration and the `{gs}`-free default preset, so `M.DEFAULTS` is unchanged.
- **Messages tab.** With `ns.GEAR_SCORE` on, `{gs}` was already in `M.TOKENS` and filled by `M.Format`. The placeholder help text now also adds ", gear score" to "the rest are you (...)", gated on the switch. With the switch off, the text is unchanged.
- **Core.lua comment.** The switch comment no longer over-promises. It now says the default request preset has no `{gs}` (players add it themselves), and that a saved copy of the old GS preset was reset for good.
- **GEARSCORE.md.** The "How to re-enable" section now says where `{gs}` comes back: the key list, the help text and `M.Format`. It also says a "Default" click gives the preset without `{gs}`, and that the `M.Init` migration of the saved text cannot be undone by the switch.

### WR-03: `StoreSelf` retries forever, and each equipment change starts another chain

**Files modified:** `GearScore.lua`
**Commit:** 2c08725
**Applied fix:**
- **Retry cap.** `StoreSelf(tries)` now stops after `ITEM_RETRIES` more tries, the same cap `Read` uses.
- **One chain at a time.** A `selfPending` flag keeps only one retry chain running. `PLAYER_EQUIPMENT_CHANGED` and `PLAYER_ENTERING_WORLD` go through `QueueStoreSelf()`, which waits one second and does nothing while a chain is pending. `GS.ScanGroup` makes its immediate attempt only when no chain is pending.
- **Tested.** In the harness, five equipment changes queue a single timer, a chain whose items never load stops after 4 runs, and a new chain can start afterwards.

### WR-04: No `issecretvalue` guards on unit names and GUIDs in the inspect path

**Files modified:** `Core.lua`, `GearScore.lua`
**Commit:** b869e80
**Applied fix:**
- **`ns.Short`** returns nil for anything that is not a readable string. That covers secret values, and the check runs only where the `issecretvalue` global exists.
- **Guards in `GearScore.lua`.** A local `Secret()` helper, like the one in `Listings.lua`, is used in three places:
  - `GS.ScanGroup` skips members whose name gives no short name.
  - `Next()` skips units with a secret name or GUID, or no GUID.
  - The `INSPECT_READY` handler ignores a secret argument.
- **Callers.** `GS.Store` and `GS.Lookup` already handled a nil short name. `Listings.lua`'s callers already check `Secret()` (and `type == "string"` in `Names`) before calling `ns.Short`, so they still work.
- **Tested.** The harness covers secret party names and GUIDs, a readable unit still being inspected, and `INSPECT_READY` with a secret argument.

## Skipped Issues

### WR-01: Public store releases ship without the GPL licence text

**File:** `.pkgmeta:17`
**Reason:** skipped: author convention, deferred to Phase 5 Release Review. Leaving `LICENSE` out of the package matches the sister addon TerribleBuffTracker. `.pkgmeta` was not edited.
**Original issue:** `LICENSE` is in the packager's ignore list, so the release zip has no copy of the licence while this phase enables CurseForge/Wago uploads.

---

_Fixed: 2026-11-11T16:45:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
