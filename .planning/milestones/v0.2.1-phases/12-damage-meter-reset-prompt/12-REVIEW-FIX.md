---
phase: 12-damage-meter-reset-prompt
fixed_at: 2026-11-16T00:00:00Z
review_path: .planning/phases/12-damage-meter-reset-prompt/12-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 6
skipped: 1
status: partial
---

# Phase 12: Code Review Fix Report

**Fixed at:** 2026-11-16
**Source review:** .planning/phases/12-damage-meter-reset-prompt/12-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (all, approach decided by the orchestrator)
- Fixed: 6 (CR-01, WR-01, WR-02, WR-03, IN-02, IN-03)
- Skipped: 1 (IN-01, accepted as designed)

Verification: `stylua` parses and formats `MeterReset.lua` after each fix (no Lua compiler on
this machine); each change re-read. In-game check still needed (see the notes per finding).

## Fixed Issues

### CR-01: The dialog sits exactly on StaticPopup1

**Files modified:** `MeterReset.lua`
**Commit:** f5927d9
**Applied fix:** Dropped `SetToplevel(true)` (strata stays `DIALOG`, never raised above the
game's popups). New `Place(f)`, run each time the dialog opens: reads `StaticPopup1..N`
(`STATICPOPUP_NUMDIALOGS`, fallback 4) from `_G`, picks the lowest shown one by `GetBottom()`
and anchors our TOP to its BOTTOM with an 8 px gap; with none shown, `TOP, UIParent, TOP, 0,
-135`. Only reads Blizzard's frames; our frame is anchored to theirs, nothing is written to
them. Status: fixed, requires human verification (a popup that opens *after* ours, e.g. a
summon, still takes StaticPopup1's spot; ours no longer covers it because it isn't toplevel,
but check the overlap in game).

### WR-01: Each wipe-and-run-back re-asks mid-dungeon

**Files modified:** `MeterReset.lua`
**Commit:** febdd95
**Applied fix:** Remembers the instance you last left (`lastInstance`) and when (`leftAt`,
set at the loading screen that takes you out or to another instance). Entering that same
instance ID less than 15 minutes (`SAME_RUN`) after leaving doesn't ask; another instance, or
the same one after 15+ minutes, asks. Login / reload still only record. Status: fixed,
requires human verification (logic change).

### WR-02: Duplicates Details!' own erase prompt

**Files modified:** `MeterReset.lua`
**Commit:** ccf850c
**Applied fix:** `DetailsHandlesInstances()` reads `Details.segments_auto_erase` (type-checked
number; only read). When the target is Details! and the mode is 2 (ask) or 3 (erase), the
instance trigger doesn't ask. The group-join trigger is unchanged. Header comment notes it.

### WR-03: Yes can do nothing without a word

**Files modified:** `MeterReset.lua`
**Commit:** 4697dc9
**Applied fix:** `M.Ask` stores the named meter on the dialog (`dialog.target`); Yes calls
`M.Reset(f.target)`. `M.Reset(target)` checks the meter again: "Details! isn't loaded now;
nothing reset." / "the damage meter is off now; nothing reset." / "no damage meter to
reset."; a failed `pcall` prints "couldn't reset Details!: <err>" or "couldn't reset the
damage meter: <err>".

### IN-02: The group and instance triggers can ask twice

**Files modified:** `MeterReset.lua`
**Commit:** 2e72838
**Applied fix:** `lastPromptAt` is set when the dialog shows and when Yes / No is clicked.
Both triggers go through `AskFromTrigger()`, which doesn't ask within 10 s (`MERGE`) of it.
`/tgf meter` still calls `M.Ask()` directly, so it always shows.

### IN-03: CLAUDE.md's SettingsPanel line lists the old sections

**Files modified:** none (already fixed)
**Commit:** —
**Applied fix:** Verified: the `UI/SettingsPanel.lua` entry already reads "sections Item
level / Group finder / Damage meter / Messages".

### CLAUDE.md

**Commit:** 601b345
The `MeterReset.lua` line now notes: anchored below the lowest shown popup, never raised
above them; the same instance within 15 min doesn't ask; skipped when Details!'
`segments_auto_erase` asks or erases; the 10 s merge; Yes resets the named meter and reports
a failure.

## Skipped Issues

### IN-01: Yes mid-fight ends Details!' current combat

**File:** `MeterReset.lua` (Yes button)
**Reason:** Accepted as designed (orchestrator decision): Yes is the player's choice; no change.
**Original issue:** A Yes click during combat makes Details! end the current fight.

---

_Fixed: 2026-11-16_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
