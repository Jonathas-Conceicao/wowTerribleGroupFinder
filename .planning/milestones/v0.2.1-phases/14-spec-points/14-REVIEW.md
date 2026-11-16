---
phase: 14-spec-points
reviewed: 2026-11-16T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - ItemLevel.lua
  - ItemLevelUI.lua
  - Settings.lua
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-11-16
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Narrative Findings (AI reviewer)

## Summary

Reviewed `git diff 1a602cc 354953b` for `ItemLevel.lua`, `ItemLevelUI.lua` and `Settings.lua`. I checked it against the Forever branch of wow-ui-source: `Blizzard_PlayerSpells` (shared and Camelot ClassTalents), `Blizzard_UnitPopupShared` ("Inspect Talents"), `Blizzard_InspectUI` and the C_Traits docs.

What holds up:
- The data read matches `ClassTalentsFrameMixin:RefreshTreeHeaders`: groups in `ipairs` order, matched by `traitNodeGroupID`, `currencyInfos[1].spent`, and a missing group counts 0.
- The tooltip and probe paths contain no new taint-relevant writes. `PlayerSpellsFrame:IsInspecting()` only reads fields, and `PlayerSpellsFrameMixin:OnHide` clears the inspect unit, so the new `Busy()` guard cannot stick after the frame closes.
- The settings changes are correct: the section header is emitted on change, `specPoints` defaults on, and `/tgf set specpoints` matches through `opt.key:lower()`.

The problems are in how far the inspect-config read can be trusted:
- It ignores the game's own validity flag (`C_Traits.HasValidInspectData`).
- The new "Inspect Talents" guard only covers the frame once it shows, not while its inspect is still pending.
- The probe's talent printer is not error-proof, although its comment says it is, and it runs inside the inspect answer path.

## Warnings

### WR-01: Inspect config is read without `C_Traits.HasValidInspectData()`, and an invalid read is cached as final

**File:** `ItemLevel.lua:779` (ReadCurrent), `ItemLevel.lua:1022` (foreign `Try`), `ItemLevel.lua:180-240` (ReadTalents)
**Issue:** `ReadTalents(INSPECT_CONFIG)` reads config `-1` with no check that it holds valid inspect data. Blizzard gates its own use of that config with `C_Traits.HasValidInspectData()`, which enables or disables the "Inspect Talents" button in `Blizzard_InspectUI/Mainline/InspectPaperDollFrame.lua:68-71`.

Whether `ClearInspectPlayer()` (called in `Done`) empties config `-1` is still open (HUMAN-UAT item 2). If it does not, and an answer arrives without trait data (a low-level player, or a server answer that only carries items), the config still holds the previous inspectee's trees. Those trees are then stored under the new GUID. The code has no cross-check: the tree comes from the config itself, not from the unit's class.

The opposite failure is also cached for the whole session. An invalid read gives `false`, `TalentsKnown` then returns true, and `Done(c, ilvl ~= nil)` counts only the item level. So a player whose item level is known is never inspected again, and their talents line never shows this session.
**Fix:** Treat invalid inspect data as "not answered", not as "answered, nothing readable":
```lua
local function ReadInspectTalents()
	if C_Traits and C_Traits.HasValidInspectData then
		local ok, valid = pcall(C_Traits.HasValidInspectData)
		if not ok or Secret(valid) or not valid then
			return nil -- unknown: don't cache, let RETRY_AFTER try again
		end
	end
	return ReadTalents(INSPECT_CONFIG) or false
end
```
Use it at both capture sites. In `ReadCurrent`, also pass `gotValue = ilvl ~= nil and c.talents ~= nil` to `Done`, so `tried[guid]` rate-limits a talents-only miss as well. Optionally reject a read whose `treeIDs[1]` does not belong to `UnitClass(unit)`.

### WR-02: A pending "Inspect Talents" is guarded for only 2 s; a quiet inspect can take the slot and clear it

**File:** `ItemLevel.lua:712-714` (Busy), `ItemLevel.lua:745-760` (Done)
**Issue:** Forever's unit menu "Inspect Talents" (`UnitPopupSharedButtonMixins.lua:338-350`) calls `NotifyInspect(unit)`. It opens `PlayerSpellsFrame` only when `INSPECT_READY` for that GUID arrives.

Until then, `TalentsInspecting()` is false, and the only guard is `OTHERS_BUSY` (2 s after `OnNotify`). The Inspect window has a pending guard of `INSPECT_WAIT` (4 s) via `InspectFrame.unit`; this flow has nothing like it.

If the answer takes longer than 2 s, a tooltip hover can start our quiet inspect. Our `Done` then passes every condition (`serial == c.serial`, `othersAt < c.sentAt`) and calls `ClearInspectPlayer()`. When the menu's answer lands, Blizzard opens the talent view on a cleared config or on our target's data. This is the Pitfall 3 scenario the phase meant to close, with a gap left before the frame shows.
**Fix:** Treat a foreign `NotifyInspect` as pending until its own `INSPECT_READY` or `INSPECT_WAIT`, whichever comes first:
```lua
local othersPendingGUID, othersPendingAt = nil, -math.huge
-- OnNotify, not sending: othersPendingGUID, othersPendingAt = lastTarget, GetTime()
-- OnInspectReady: if guid == othersPendingGUID then othersPendingGUID = nil end
local function OthersPending()
	return othersPendingGUID ~= nil and GetTime() - othersPendingAt < INSPECT_WAIT
end
-- Busy(): ... or OthersPending()
```

### WR-03: `PrintTalents` can throw; it runs inside the `INSPECT_READY` answer path, and its comment says it never errors

**File:** `ItemLevel.lua:520-585` (notably 546, 553-560), called from `ItemLevel.lua:804` and `ItemLevel.lua:632`
**Issue:** The comment says "Never errors: every call is pcall'd", but only the C API calls are wrapped in pcall. The group and currency loops run unprotected and do not check for secret values: they compare `c.traitNodeGroupID == g.groupID`, index `g.groupID`, `g.orderIndex`, `g.displayName` and `first.spent`, and iterate `currency` and `groups`. A secret value there raises an error. `ids` can also get holes (`ids[i] = ... or nil`) before it is passed to `GetGroupCurrencyInfo`.

Where the error lands:
- In `ReadCurrent` (non-quiet path), the error comes after `Remember` and before `Done`. That skips `ClearInspectPlayer()` and keeps `current` set until the `INSPECT_WAIT` timer runs `Done(c, false)`. Meanwhile it also sets `tried`, the probe stalls for 4 s, and the error goes to the event handler.
- In `ProbeSelf`, the error aborts `/tgf ilvl` before the group is queued.

`ReadTalents` is written fail-closed; the probe printer is not.
**Fix:** Run the whole printer under one pcall at its call sites, so a probe failure can never skip `Done`:
```lua
local ok, err = pcall(PrintTalents, INSPECT_CONFIG, true)
if not ok then Print("  talents probe failed: " .. tostring(err)) end
```
Alternatively, apply the same `Secret()` checks `ReadTalents` uses inside the loops. Either way, correct the comment.

### WR-04: The order rule depends on our post-call running last; lines added on refresh land under other addons' lines, and a late item level is dropped

**File:** `ItemLevelUI.lua:154-197` (RefreshTooltip, esp. 180 and 186-191)
**Issue:** `RefreshTooltip` appends with `AddLine` at the bottom of the tooltip. If another `TooltipDataProcessor` post-call (another addon, or a later game line) added lines after our build, a talents line that arrives on refresh lands below them, not "right after the item level line" as 14-CONTEXT requires.

Also, `elseif not lines.talents.text` drops the item level for that tooltip's life whenever the talents line is already there. This happens now that `Remember` stores talents even when items are incomplete (talents captured on the first pass, item level known only after `ITEM_RETRIES`, or on the 30 s re-inspect). The line index is tracked, so the line can be placed correctly.
**Fix:** When the line it should follow exists (`lines.ilvl.index` for talents, or the talents line for a late item level), insert at that position. The tooltip API has no insert, so re-run the build: `GameTooltip:RefreshData()` when available, which re-fires the post-call that adds both lines in order. Keep `AddLine` as the fallback only when `RefreshData` is missing.

## Info

### IN-01: Own tooltip counts staged (unapplied) talent clicks

**File:** `ItemLevel.lua:453-458` (TalentsOf, `me` branch)
**Issue:** `GetGroupCurrencyInfo` on the active config likely includes staged purchases while the talent frame is open (research Pitfall 8, HUMAN-UAT 4), so your tooltip can show points you never applied.
**Fix:** If UAT confirms it, read with `C_Traits.GetTreeCurrencyInfo(configID, treeID, true)` (`excludeStagedChanges`) as a cross-check, or skip the own line while `C_Traits.ConfigHasStagedChanges(configID)` is true.

### IN-02: `OwnConfigID` accepts a candidate whose type can't be read, which contradicts its comment

**File:** `ItemLevel.lua:265-275`
**Issue:** `fits` starts true and is cleared only when `t` is a readable number that differs from `want`. If `GetConfigInfo` fails, or the type is secret or missing, the candidate is accepted. The comment says "A candidate of another config type is rejected", which is only true when the type is readable.
**Fix:** Either reword the comment ("rejected only when its type reads as another type"), or require `t == want` when `want` exists.

### IN-03: `TalentsInspecting` also blocks inspects while the frame views a loadout string

**File:** `ItemLevel.lua:296-306`
**Issue:** `PlayerSpellsFrameMixin:IsInspecting()` is true for `inspectString` (viewing a shared loadout link) as well as `inspectUnit`. In that mode the frame does not use config `-1`. Still, quiet inspects stop and `Done` skips `ClearInspectPlayer()` for as long as the frame shows.
**Fix:** Guard on `PlayerSpellsFrame:GetInspectUnit() ~= nil`, which is still a read only.

### IN-04: Dead branch in `Remember`

**File:** `ItemLevel.lua:388-390`
**Issue:** Both callers always pass non-nil talents (`ReadTalents(...) or false`), so `not r.complete and talents == nil` can never be true. If WR-01 is fixed by passing `nil` for invalid data, the branch becomes live again. Decide which behaviour is intended and keep the comment in sync.
**Fix:** Remove the branch, or keep it deliberately as part of the WR-01 fix.

### IN-05: Talents are frozen for the session once cached

**File:** `ItemLevelUI.lua:142`, `ItemLevel.lua:467-473`
**Issue:** `TalentsKnown` stays true after the first answer, including `{0,0,0}` for a low-level player. When the item level is also known, nothing triggers another quiet inspect, so a respec or newly spent points show only after someone else's inspect. This matches the "only updated by a later inspect" decision, but players will see stale talent points (for example a fresh 10 shown with no line at all).
**Fix:** Document this in the option tooltip or CLAUDE.md. Alternatively, let an all-zero entry expire after `RETRY_AFTER`, so low-level players are re-read.

---

_Reviewed: 2026-11-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
