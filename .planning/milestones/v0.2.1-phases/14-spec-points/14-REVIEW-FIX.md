---
phase: 14-spec-points
fixed_at: 2026-11-16T00:00:00Z
review_path: .planning/phases/14-spec-points/14-REVIEW.md
iteration: 1
findings_in_scope: 9
fixed: 6
skipped: 3
status: partial
---

# Phase 14: Code Review Fix Report

**Fixed at:** 2026-11-16
**Source review:** .planning/phases/14-spec-points/14-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 9 (4 warnings, 5 info; the orchestrator decided the approach for each)
- Fixed: 6
- Skipped: 3 (IN-01 and IN-03 by decision; IN-04 kept on purpose, see below)

Worked on the current branch in the main working tree, as the orchestrator asked (no worktree). `stylua .` was run after each fix. The session smoke harness ends `SUMMARY: 0 failed` in all three modes ("", `--fallback`, `--attach`): 1033 passes in the default mode, up from 1002.

## Fixed Issues

### WR-01: Inspect config is read without `C_Traits.HasValidInspectData()`, and an invalid read is cached as final

**Files modified:** `ItemLevel.lua`
**Commit:** 94a6a2e
**Applied fix:** A new `ReadInspectTalents()` is used at both capture sites (`ReadCurrent`, foreign `Try`). When `C_Traits.HasValidInspectData` exists and reports invalid data (or errors, or returns a secret), it returns `nil`. `nil` means unknown, so `TalentsKnown` stays false and a later inspect can fill the talents. Otherwise it returns `ReadTalents(-1) or false`, as before.

`Done`'s "got a value" is now `type(c.talents) == "table" or (ilvl ~= nil and not c.hadIlvl)`. `c.hadIlvl` is recorded when the inspect is sent. So:
- Talents brought count as success, even when the item level isn't known.
- A player with a known item level but unknown talents is inspected again under the normal pacing.
- An inspect for talents alone that brings none waits `RETRY_AFTER` (30 s). This stops a loop of re-inspects, 1.5 s apart, on every hover if the game keeps reporting invalid data. That is a narrow reading of "existing pacing rules".

**Needs human verification:** this is a logic change. In game, check that `HasValidInspectData()` is true after a normal inspect answer on Forever. If it never is, talents never show for other players.

### WR-02: A pending "Inspect Talents" is guarded for only 2 s; a quiet inspect can take the slot and clear it

**Files modified:** `ItemLevel.lua`
**Commit:** 2ec0f4c
**Applied fix:** A `NotifyInspect` that isn't ours now records `othersPendingAt` and `othersGUID`. `OthersPending()` stays true until an `INSPECT_READY` for that GUID arrives or `INSPECT_WAIT` (4 s) passes. An unreadable GUID waits the full 4 s.
- `Busy()` adds `OthersPending()`. The 2 s `OTHERS_BUSY` gap is kept.
- `Done` skips `ClearInspectPlayer()` while it is pending.

The pending clock is separate from `othersAt`. Otherwise the `InspectUnit` hook, which also sets `othersAt`, revived a stale flag; the harness caught this.

**Needs human verification:** guard timing logic.

### WR-03: `PrintTalents` can throw inside the `INSPECT_READY` answer path

**Files modified:** `ItemLevel.lua`
**Commit:** d75ca35
**Applied fix:** `SafePrintTalents` runs the whole printout under one pcall. On failure it prints "talents probe failed: ...". Both call sites (`ProbeSelf` and the probe's inspect answer in `ReadCurrent`) use it, so the probe can no longer skip `Done` or the group queue. `PrintTalents`' comment no longer claims it never errors.

### WR-04: Lines added on refresh can land under other addons' lines, and a late item level is dropped

**Files modified:** `ItemLevelUI.lua`
**Commit:** 2dedf34
**Applied fix:** When the tooltip still shows that player and our lines would change, `RefreshTooltip` calls `Rebuild()`. `Rebuild()` calls `GameTooltip:RefreshData()` only when:
- the method and `GetPrimaryTooltipInfo` exist, and there is tooltip info to rebuild from;
- we are out of combat. A rebuild started from addon code is tainted, and per Blizzard's own comment in `GameTooltip.lua` it can drop lines that hold secret data.

The call is pcall'd. It counts as done only if our post-call actually ran: a `builds` counter is incremented in `OnTooltipUnit`. Otherwise the old append / update-in-place logic runs as the fallback.

Other safeguards:
- A `rebuilding` flag makes `RefreshTooltip` return when it is reached from inside our own rebuild, so there is no recursion.
- `AddLine` adds each line only once per build.
- When the values haven't changed, there is no rebuild at all.

Taint note: `RefreshData` is a public method. Calling it from our code means Blizzard's own method writes `shouldRefreshData` / `infoList` under our taint. That is the same kind of use as the `AddLine` / `Show` calls already made on `GameTooltip`, and nothing of ours is written to it.

**Needs human verification:** in game, with another tooltip addon loaded too, check that a late answer redraws the tooltip with "Item Level" then "Talents", with no duplicate lines and no flicker.

### IN-02: `OwnConfigID` accepts a candidate whose type can't be read, which contradicts its comment

**Files modified:** `ItemLevel.lua`
**Commit:** 9ea4d67
**Applied fix:** The code now matches the comment:
- A candidate whose type reads `CamelotCombat` wins.
- A candidate whose type can't be read is taken only when it is the only candidate. Candidates are de-duplicated, since both APIs usually return the same ID.
- With no enum or no `GetConfigInfo`, the first candidate is used, as before.

### IN-05: Talents are frozen for the session once cached

**Files modified:** `ItemLevel.lua`
**Commit:** 5ca4e44
**Applied fix:** `Remember` stamps `talentsAt` (`GetTime()`). `TalentsKnown` counts an answer with nothing to show as known for `NOTHING_KEPT` (600 s) only; after that the tooltip asks for an inspect again. "Nothing to show" covers both `false` and an all-zero list. The decision named `false` only, but a low-level player's valid inspect most likely reads as `{0,0,0}`, which is the case the finding describes. Real figures are kept, and any later inspect updates them as before.

## Skipped Issues

### IN-01: Own tooltip counts staged (unapplied) talent clicks

**File:** `ItemLevel.lua:453-458`
**Reason:** No change, by the orchestrator's decision: the in-game check (HUMAN-UAT 4) comes first.
**Original issue:** `GetGroupCurrencyInfo` on the active config likely includes staged purchases while the talent frame is open.

### IN-03: `TalentsInspecting` also blocks inspects while the frame views a loadout string

**File:** `ItemLevel.lua:296-306`
**Reason:** No change, by the orchestrator's decision: harmless (only more cautious).
**Original issue:** `IsInspecting()` is also true for `inspectString`, which pauses quiet inspects and our clear while a shared loadout is viewed.

### IN-04: Dead branch in `Remember`

**File:** `ItemLevel.lua` (`Remember`)
**Reason:** I kept the branch instead of removing it, against the decided approach, because WR-01 made it live again, as the review predicted. `ReadInspectTalents()` now returns `nil` for invalid data, so `not r.complete and talents == nil` happens: the items never loaded and the talent data is invalid. In that case there is nothing to store. Removing the branch would create an empty cache entry and notify every `OnLearned` observer for nothing. The comment above `Remember` and the branch's own comment ("nothing to store") now say this; the change is part of commit 94a6a2e.
**Original issue:** Both callers passed non-nil talents, so the branch could never be reached.

## Smoke harness changes (session scratchpad)

- `harness.lua` (head): `TooltipDataProcessor.AddTooltipPostCall` also keeps every post-call in `__tipPosts`, so a stubbed `RefreshData` can run all registered post-calls, as a real rebuild does. The harness loads several ItemLevelUI instances.
- `tail.lua`, "ilvl guard" case 3: the old expectation "one inspect 2.5 s after another" is obsolete under WR-02. It now expects no inspect while the foreign one hasn't answered, and one inspect once it has. A new case checks that an unanswered foreign inspect is still pending at 3.5 s and stops being pending after `INSPECT_WAIT`.
- `tail.lua`: a new probe, "talents review fixes 14" (source `t14fix.lua`, inserted by `ins14fix.js`), covers:
  - WR-01: invalid data stays unknown; re-inspect pacing; a talents-only success.
  - WR-04: one rebuild with ordered lines; no rebuild for unchanged values; a late item level lands above the talents line; the in-combat, missing-`RefreshData` and no-post-call fallbacks.
  - IN-05: the 10-minute expiry, and that real figures never expire.
  - IN-02: config choice.

## Documentation

- `CLAUDE.md`: the `ItemLevel.lua` and `ItemLevelUI.lua` lines are updated for the pending foreign inspect, `HasValidInspectData`, the 10-minute re-read, the config choice, the pcall'd probe printout and the `RefreshData` rebuild. Commit 3639906.

---

_Fixed: 2026-11-16_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
