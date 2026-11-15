---
phase: 07-item-level-spots
reviewed: 2026-11-14T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - ItemLevel.lua
  - ItemLevelUI.lua
  - Core.lua
  - TerribleGroupFinder.toc
findings:
  critical: 1
  warning: 3
  info: 7
  total: 11
status: issues_found
fixed_at: 2026-11-14
fixed: [CR-01, WR-01, WR-02, WR-03, IN-02, IN-03, IN-04, IN-06, IN-07]
not_in_fix_scope: [IN-01, IN-05]
fix_status: partial
---

# Phase 07: Code Review Report

**Reviewed:** 2026-11-14
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the phase diff (`2911adf..HEAD`): the quiet inspect guard in `ItemLevel.lua` (serial, lastTarget, othersAt, ClearInspectPlayer conditions), the four display spots in the new `ItemLevelUI.lua`, the `Core.lua` init call and the TOC load order. I checked them against the Forever (`camelot`) Blizzard source: `Blizzard_InspectUI/Camelot/Blizzard_InspectUI.lua`, `Mainline/InspectPaperDollFrame.lua`, `Blizzard_UIPanels_Game/Camelot/CharacterFrame.lua` / `PaperDollFrame.lua` / `PaperDollFrameConstants.lua`, `Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua` and `TooltipComparisonManager.lua`.

What works:
- The TOC order is right (Settings, then ItemLevel, then ItemLevelUI).
- The tooltip line post-call adds the line right under the name, because `lineIndex` is set before post-calls run and later lines follow our added line.
- Compare tooltips get a fresh info table and `ClearLines()` on every build, so the line is not added twice.
- The `MOVESPEED` + 1 insertion lands at the end of the General category, so the row stripes stay correct.
- The serial and GUID checks correctly drop stale answers.

The main defect: the "pending" half of the Inspect window guard trusts `InspectFrame.unit`. Forever's Inspect UI never clears that field while the window is hidden, so one unanswered Inspect request turns quiet inspects off for the rest of the session. Other concerns:
- Truthiness tests run on values that may be secret, and a secret answer counts as "not hostile" (fail-open).
- The character sheet row disappears for the whole of every combat.
- Writing into the stats pane's `elementData` spreads taint into secure ScrollBox callbacks and gamepad navigation.

## Critical Issues

### CR-01: A stale `InspectFrame.unit` turns off quiet inspects for the session

**File:** `ItemLevel.lua:361-367` (`InspectOpen` / `Busy`), also `ItemLevel.lua:398` (`Done`)

**Issue:** `InspectOpen()` counts the window as "pending" whenever `InspectFrame.unit ~= nil`. On Forever, `InspectFrame_Show` (`Blizzard_InspectUI/Camelot/Blizzard_InspectUI.lua:41-50`) sets `InspectFrame.unit = unit` and then waits for `INSPECT_READY` before it calls `ShowUIPanel`. The field is cleared only in `OnLoad`, in `OnHide` (which never fires for a frame that was never shown) and when `CanInspect` refuses. The `PLAYER_TARGET_CHANGED` / `GROUP_ROSTER_UPDATE` handling returns early with `if not self:IsShown() then return end`.

So whenever an Inspect request goes unanswered, `InspectFrame.unit` stays set indefinitely. Blizzard's own comment admits the server drops answers when flooded, and the target can also move out of range or log off. As a result:
- `Busy()` is true forever, so `ILvl.RequestInspect` returns at once on every tooltip. The player tooltip spot silently stops learning new players.
- The `/tgf ilvl` probe prints "waiting: in combat or the Inspect window is open." every 3 s and never progresses.
- `Done` never calls `ClearInspectPlayer`.

Nothing recovers it except a later successful Inspect window open and close.

**Fix:** Bound the "pending" state in time instead of trusting the field. `OnInspectUnit` already stamps the time:
```lua
local inspectUnitAt = -math.huge
local function OnInspectUnit()
	othersAt = GetTime()
	inspectUnitAt = GetTime()
end

local function InspectOpen()
	if InspectFrame == nil then
		return false
	end
	if InspectFrame:IsShown() then
		return true
	end
	-- pending: unit set by InspectFrame_Show, but only until its answer is overdue
	return InspectFrame.unit ~= nil and GetTime() - inspectUnitAt < INSPECT_WAIT
end
```
Keep `Done`'s `serial == c.serial` check: it already protects a window that opens later.

## Warnings

### WR-01: Hostile and unit checks test possibly secret values for truth, and fail open

**File:** `ItemLevel.lua:499-503`; also `ItemLevel.lua:229, 232, 481-483, 524`, `ItemLevelUI.lua:83, 91`

**Issue:**
1. `ILvl.Hostile` evaluates `enemy and not Secret(enemy)`. That tests `enemy` for truth before checking whether it is secret. On the modern client a truth test on a secret value from insecure code is an error, and these callbacks run under `forceinsecure()`.
2. Even where the test does not error, a secret `true` from `UnitIsEnemy` / `UnitCanAttack` makes `Hostile` return `false`. A player whose hostility can't be read is then treated as friendly: their known value is shown and an inspect may be requested. That breaks the rule "enemies, and anyone you can attack, never looked up / never shown".
3. `UnitIsPlayer`, `UnitIsUnit`, `UnitIsConnected` and `CanInspect` are tested for truth with no secret guard. The file guards GUIDs and names, so it treats secrets as possible, but these checks are not guarded the same way.

**Fix:** Check for secret first, and fail closed:
```lua
function ILvl.Hostile(unit)
	local enemy = UnitIsEnemy and UnitIsEnemy("player", unit)
	local attackable = UnitCanAttack and UnitCanAttack("player", unit)
	if Secret(enemy) or Secret(attackable) then
		return true -- unreadable: never look up or show
	end
	return enemy == true or attackable == true
end
```
Apply the same pattern (`local v = UnitIsPlayer(unit); if Secret(v) or not v then return end`) to the other unit predicates.

### WR-02: The character sheet Item Level row disappears for the whole of every combat

**File:** `ItemLevelUI.lua:252-256, 287-291`

**Issue:** Blizzard's `CharacterStatsPaneScrollBoxMixin:UpdateStats` (`Camelot/CharacterFrame.lua:1109`) rebuilds `self.elementData = {}` from scratch on every stat update, and stat updates fire constantly in combat (`UNIT_STATS`, `UNIT_AURA`, power and attack-power events). The post-hook `AddSheetRow` → `SyncSheet` returns early while `InCombatLockdown()`, so the first stat refresh after combat starts removes the row. It comes back only on `PLAYER_REGEN_ENABLED`.

`ScrollBox:SetDataProvider` is not a protected call: Blizzard's own `HideElements` calls it in combat. So the gate costs the row in every fight without avoiding a blocked action. If the gate exists to limit taint (see WR-03), it doesn't help: the tainted entry is gone the moment Blizzard rebuilds.

**Fix:** Either drop the combat gate (the operation isn't restricted), or keep it deliberately and document the disappearing row as accepted behaviour. If you keep it, at least avoid the double rebuild by checking `pane:IsVisible()` in `AddSheetRow`.

### WR-03: The inserted stats entry spreads taint into Blizzard's secure ScrollBox callbacks and gamepad navigation

**File:** `ItemLevelUI.lua:270-284`

**Issue:** The documented exception allows writing `elementData` and re-setting the provider, but the scope of the taint is wider than the comment suggests:
1. The entry inserted by our code is a tainted value in a table Blizzard created securely. `CharacterStatsPaneScrollBoxMixin:HideElements` (`CharacterFrame.lua:1078-1092`) runs from the ScrollBox's `OnUpdate` callback on every later secure layout or scroll. It reads `self.elementData[i]` for every index, ours included, which taints the rest of that secure execution.
2. Our insecure `SetDataProvider` runs Blizzard's `Initializer` for every visible row. With the gamepad UI enabled, that `Initializer` calls `SmartNavigation_MarkFrameFocusable` and `SmartNavigation_RegisterOutgoingDirNavCallback` (`CharacterFrame.lua:1049-1052, 1094-1100`). Those calls write into the shared SmartNavigation state from tainted execution.
3. Frames the pool creates during our call are created insecurely.

None of these are protected today, but this is the path most likely to show up later as `ADDON_ACTION_BLOCKED` blamed on the addon.

**Fix:** At minimum, skip the sheet spot while `InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()`. Record in the code comment that the taint reaches `HideElements`. A taint-free alternative is our own FontString parented to the stats pane, anchored below the Movement Speed row frame (found via `pane.ScrollBox:FindFrame(elementData)`). It writes no Blizzard data.

## Info

### IN-01: The item tooltip dedupe guard can suppress the line after a rebuild

**File:** `ItemLevelUI.lua:419-428`

**Issue:** The guard skips any add where `last.info == info and last.index ~= index`. `RebuildFromTooltipInfo` (`TooltipDataHandler.lua:374-386`) reprocesses the same `info` table, and for the primary info it forces `append = false` and clears the lines. If that info was first built in append mode after plain `AddLine` text, the name line's index changes on rebuild (for example from 3 to 1). The guard then reads it as "a second name line" and the item level line disappears. The `pcall` also drops errors silently.

**Fix:** Clear `lastAdd[tooltip]` in a tooltip pre-call (`TooltipDataProcessor.AddTooltipPreCall(TooltipDataProcessor.AllTypes, ...)`), so the guard spans exactly one build. Then compare only `last.info == info`. Report `pcall` failures once through `UI.failed.item`.

### IN-02: The Inspect window retry counter is not reset when the window closes

**File:** `ItemLevelUI.lua:143, 177-183, 214-216`

**Issue:** `retryGuid` and `retryCount` survive `OnHide`. Reopening the Inspect window on the same player whose value is still unknown gets zero timed retries, and only the hooks and `OnLearned` can fill the text.

**Fix:** In the `OnHide` hook, also set `retryGuid, retryCount = nil, 0` and bump `retryToken`.

### IN-03: The player tooltip keeps an outdated value when a later inspect updates it

**File:** `ItemLevelUI.lua:98`

**Issue:** `RefreshTooltip` returns when `lineFor == guid`. If a later inspect (the probe's or the Inspect window's) changes the value while the tooltip is up, the old number stays until the tooltip is rebuilt.

**Fix:** Store the value next to `lineFor`. On a change, call `GameTooltip:RefreshData()` instead of `AddLine`.

### IN-04: A late answer to our own timed-out inspect is handled as "someone else's"

**File:** `ItemLevel.lua:459-466, 621-650`

**Issue:** After `INSPECT_WAIT`, `Done` calls `ClearInspectPlayer` but leaves `lastTarget` set to our GUID. A late `INSPECT_READY` then passes `guid == lastTarget` and takes the "Someone else's inspect" branch. It reads inventory that was already cleared, so up to three 1 s retries end in nothing.

**Fix:** In `Done`, when we cleared, also clear `lastTarget = nil` (and `readyGUID`), so the late answer counts as stale.

### IN-05: `Done` clears the inspect without Blizzard's `PlayerSpellsFrame:IsInspecting()` check

**File:** `ItemLevel.lua:398`

**Issue:** Blizzard's `InspectFrameMixin:OnHide` only calls `ClearInspectPlayer` when `not PlayerSpellsFrame or not PlayerSpellsFrame:IsInspecting()`. Ours skips that check. The Camelot Inspect window has no talents button today, so this has no visible effect now, but it diverges from Blizzard's guard.

**Fix:** Add `and not (PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting())` to the condition.

### IN-06: The probe's `Next` chains can run in parallel and print "waiting" twice

**File:** `ItemLevel.lua:378, 405, 474-477`

**Issue:** `Displaced` and `Done` each schedule `Next`, and `Next` reschedules itself while `Busy()`. After a displacement during a busy period, two timer chains run at once and each prints "waiting: ..." every 3 s.

**Fix:** Keep a single pending-`Next` flag (or a token) and schedule only when none is pending.

### IN-07: `UI.Install` marks the Inspect spot installed before its real setup runs

**File:** `ItemLevelUI.lua:198-235`

**Issue:** `InspectText` returns `true` as soon as it registers `ContinueOnAddOnLoaded`. If `OnInspectLoaded` fails later, the spot is in both `installed` and `UI.failed`. A partial failure also leaves `inspectText` created, so the early return in `OnInspectLoaded` blocks any retry. Your own item level (`ILvl.Of` → `GameMine`) also ignores `C_PaperDollInfo.GetMinItemLevel`, while the character sheet shows `max(minItemLevel, equipped)` (`PaperDollFrame.lua:1384-1387`). The two can differ wherever a minimum item level applies.

**Fix:** Create `inspectText` only after the hooks succeed, or nil it in the error path. For your own value, use `math.max(GetMinItemLevel() or 0, equipped)` to match the sheet.

## Fix Notes

Fixed 2026-11-14 (gsd-code-fixer). Smoke harness: 0 failed in all three modes (default, `--fallback`, `--attach`), with new checks for CR-01, WR-01, WR-02/03, IN-02, IN-03, IN-04, IN-06 and IN-07.

| Finding | Status | Commit | What changed |
|---------|--------|--------|--------------|
| CR-01 | fixed | b9b1e87 | `InspectOpen()`: a shown window always counts; a set `InspectFrame.unit` counts as pending only up to `INSPECT_WAIT` after the `InspectUnit` hook (`inspectUnitAt`). `Done` keeps its `serial == c.serial` check. |
| WR-01 | fixed | 59a8fae | `Secret()` asks `issecretvalue` first, with no comparison before it. New `ILvl.Yes(v)` is true only for a readable true. `Hostile` returns true on a secret answer (fail closed). Every `UnitIsPlayer`, `UnitIsUnit`, `UnitExists`, `UnitIsConnected` and `CanInspect` result, and every unit token and GUID, is checked for secret before any truth test, in both files. |
| WR-02 | fixed | 1c765b4 | The combat gate, `sheetPending` and the `PLAYER_REGEN_ENABLED` redraw are removed. The row stays through combat: `SetDataProvider` is not restricted, and Blizzard's own `HideElements` calls it in combat. No `IsVisible` gate in `AddSheetRow`: Blizzard may call `UpdateStats` before the pane is visible, and the gate would drop the row until the next update. |
| WR-03 | fixed (partly; see below) | 1c765b4 | The row is left out while `InputUtil.IsGamepadUIEnabled()` is true. `elementData` and the provider are touched only when our row is missing or must go (already true before; now covered by a check). The comment records the taint path. Option A is kept; no switch to Option B. |
| IN-02 | fixed | a0b70da | The `InspectFrame` `OnHide` hook resets `retryGuid` and `retryCount` and bumps `retryToken`. |
| IN-07 | fixed | a0b70da, e0560c3 | `inspectText` is assigned only after every hook went in (the hooks act on nothing before then). A failed setup clears `installed.inspect`, so the spot is listed only as failed. Your own value (`ILvl.Of`, `ILvl.Inspected`, the probe's "tooltip shows" line) is `max(GetMinItemLevel, equipped)` as on the sheet. The probe's exactness check still uses the raw equipped figure. |
| IN-04 | fixed | 2b74795 | When `Done` clears, it also sets `lastTarget` and `readyGUID` to nil, so a late answer is dropped as stale. |
| IN-06 | fixed | d90c00b | `ScheduleNext(delay)` keeps a single pending `Next` timer. `Displaced`, `Done` and a busy `Next` all go through it. |
| IN-03 | fixed | c93fb87 | `AddLine` records our line's text and index. When a later value for the same GUID arrives, `RefreshTooltip` rewrites that `GameTooltipTextLeftN` in place, but only while it still holds our text (secret-checked). It never adds a second line. `RefreshData` is not used: there is no Lua-side source for it on Forever. |
| IN-01 | not in fix scope | — | Not requested this pass. |
| IN-05 | not in fix scope | — | Not requested this pass (no visible effect on Camelot today). |

**For the deferred in-game taint check (WR-03, still open):**
- The inserted `ITEMLEVEL` entry is still an insecure table inside Blizzard's `elementData`. `CharacterStatsPaneScrollBoxMixin:HideElements` reads it on every later ScrollBox `OnUpdate`.
- Our `SetDataProvider` call (only when the row is missing, i.e. after each Blizzard `UpdateStats`, in and out of combat) runs the pane's element initializer insecurely and may create pooled stat frames insecurely.
- What to watch in game: `/console taintLog 1` (or 2). Open the character sheet, enter and leave combat with the sheet open, scroll the stats pane, and switch the Character / Reputation / Currency tabs. Check for `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` blamed on TerribleGroupFinder, and for taint lines that run through `CharacterStatsPaneScrollBox`, `HideElements` or `SmartNavigation`.
- The gamepad UI path is excluded, so it needs no check.
- If the check finds taint, the fallback is the locked Option B (write `PAPERDOLL_STATCATEGORIES` once), or the taint-free alternative from WR-03: our own FontString anchored under the Movement Speed row frame.

---

_Reviewed: 2026-11-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
