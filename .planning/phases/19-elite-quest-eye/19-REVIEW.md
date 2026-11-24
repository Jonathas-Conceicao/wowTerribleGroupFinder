---
phase: 19-elite-quest-eye
reviewed: 2026-11-24T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - QuestButton.lua
  - UI/InPlace.lua
  - Core.lua
  - TerribleGroupFinder.toc
findings:
  critical: 1
  warning: 3
  info: 4
  total: 8
status: fixed
---

# Phase 19: Code Review Report

**Reviewed:** 2026-11-24
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

The tracker hook is sound. `usedBlocks[template][id]` is walked correctly as two levels, and the hook is a post-hook inside a pcall. The only write on Blizzard's tracker is the `HeaderText` RIGHT anchor, which `Reset` and `SetHeader` reset on every layout. Upvalue order is fine: `hint` and `outline` are declared before `Cleanup`, and `Q.*` is only reached at call time. No SetSearchTo*, no writes on LFGListingFrame or its buttons, no restricted calls. The `IP.OpenMessages` refactor keeps its behaviour, because the combat check is now in `ShowFinder` and was already in `OpenMessages`.

One real functional bug: `HasGameEye` also matches the quest item button.

## Critical Issues

### CR-01: HasGameEye matches Blizzard's quest item button, so elite quests with a quest item never get an eye

**File:** `QuestButton.lua:107-120` (used at `:232`)
**Issue:** `Blizzard_QuestObjectiveTracker.lua:309-312` adds the find-group button first and the item button second. `block.rightEdgeFrame` is "the latest frame added", so for any quest with a usable item it is the item button. `QuestObjectiveItemButtonMixin:SetUp` (`Blizzard_ObjectiveTrackerShared.lua:108-109`) does `SetAttribute("questID", ...)` and the item button has an `Icon`. `HasGameEye` therefore returns true for every quest that shows an item button, and `UpdateBlock` hides our eye. That is exactly the case the code elsewhere plans for: `Place` anchors to `rightEdgeFrame` and the combat guard handles `rightEdgeFrame`. Those paths are mostly unreachable as written.
`HasGameEye` is also redundant. `Eligible()` already drops quests where `C_LFGList.CanCreateQuestGroup` is true, which is the condition under which Blizzard adds its eye.
**Fix:** Delete `HasGameEye` and its use at `:232`. If a guard is wanted, check the frame's type, not its attributes:
```lua
local function HasGameEye(block)
	local r = block.rightEdgeFrame
	local mixin = QuestObjectiveFindGroupButtonMixin
	return type(r) == "table" and mixin ~= nil and r.OnClick == mixin.OnClick
end
```
This still misses a game eye that sits left of an item button. `Eligible`'s `CanCreateQuestGroup` check covers that case.

**Status: fixed (53347b2).** `HasGameEye` deleted. Verified in the forever source: `Blizzard_QuestObjectiveTracker.lua` adds the find-group button only when `QuestUtil.CanCreateQuestGroup(questID)` and then the item button, so `rightEdgeFrame` is the item button when both exist. `Eligible`'s `C_LFGList.CanCreateQuestGroup` guard is the same condition and also covers an eye left of an item button, so the mixin check would be redundant and could only misfire.

## Warnings

### WR-01: Hint cleanup resizes LFGParentFrame at PLAYER_REGEN_DISABLED, and the widened Listing is a stretch, not a strip

**File:** `QuestButton.lua:451-459, 617-626`; `UI/InPlace.lua:436-449`
**Issue:** Entering combat runs `hint:Hide()`, then `Cleanup()`, then `WidenListing(0)`, then `LFGParentFrame:SetWidth(...)` in combat. Browse already resizes the frame, but not at the moment combat starts. `LFGParentFrame` is a toplevel UIPanel-style frame with a `HitRectInsets` hit rect, so resizing it under lockdown should be checked in game. Also, `LFGListingFrame` is `setAllPoints` on the parent. `RolesSection` is anchored TOPLEFT/TOPRIGHT, and the whole Listing tab stretches by 252 px, so the hint overlays stretched content. It does not sit in a new strip. This needs an in-game look.
**Fix:** If the combat resize misbehaves, defer it to `PLAYER_REGEN_ENABLED`: hide the hint and outline at once, and resize the parent once combat ends. If the stretch looks wrong, anchor the hint outside `LFGListingFrame`'s right edge instead.

**Status: fixed (c9389c7), look still an in-game check.** `IP.WidenListing(0)` in combat now defers the width restore to `PLAYER_REGEN_ENABLED` (hint and outline hide at once); a widen in combat is refused. The stretch-versus-strip look is unchanged and left for the author's in-game check.

### WR-02: `Q.failed` is overwritten by `Q.Init` after a synchronous failure

**File:** `QuestButton.lua:296-330`
**Issue:** `EventUtil.ContinueOnAddOnLoaded` runs its callback at once when `Blizzard_ObjectiveTracker` is already loaded. If `HookModules()` then returns 0, the callback sets `Q.failed = "no tracker module"`. `Install` still returns true, and `Q.Init` runs `Q.failed = nil` at `:328`. `/tgf quest` then hides the failure.
**Fix:** Set `Q.failed = nil` before `pcall(Install)`, and only set it to non-nil afterwards.

**Status: fixed (53347b2).**

### WR-03: Header room relies on `GetNumLines()` right after an anchor change

**File:** `QuestButton.lua:190-205`
**Issue:** The line-count check reads `text:GetNumLines()` immediately after `SetPoint("RIGHT", ...)`. Whether the font string re-wraps synchronously is not guaranteed. If it does not, the check never detects a wrap and the title can gain a line that the block height (already computed by the layout) does not cover, so the text overlaps the next block. A `SetHeader` outside a layout (the block's anchor reset to `rightEdgeOffset`) also drops our room until the next `EndLayout`, so the title runs under the eye in the meantime.
**Fix:** Compare `text:GetStringWidth()` with the new available width (`block:GetWidth() + target`), or force a measure (`text:GetHeight()` after `SetHeight(0)`, as `SetStringText` does). Keep the restore branch.

**Status: fixed (53347b2).** `MakeRoom` resets the anchor to base, then compares the unbounded string width with the width plus the narrowing; the restore branch is kept. The title running under the eye between a `SetHeader` and the next `EndLayout` is not addressed (the layout re-runs our pass).

## Info

### IN-01: The combat guard hides item-quest eyes only at the next layout

**File:** `QuestButton.lua:238-243, 307-316`
**Issue:** Only `PLAYER_REGEN_ENABLED` is registered, so eyes already anchored to the secure item button stay shown after combat starts and vanish at the next layout. The result is inconsistent (the eye is visible, a click then refuses in combat). After CR-01 is fixed this path is reachable. Anchoring a non-secure frame to a secure frame is allowed in combat, so the guard may be stricter than needed.
**Fix:** Either register `PLAYER_REGEN_DISABLED` and hide the eyes, or drop the guard.

**Status: skipped.** Left as is; it is only a cosmetic inconsistency and the click already refuses in combat.

### IN-02: `IP.ShowFinder` toggle fallback does not switch the tab

**File:** `UI/InPlace.lua:466-471`
**Issue:** When only `LFGVanilla_ToggleFrame` exists and the frame is already shown, nothing happens and `true` is returned. `Q.Click` then calls `ShowHint`, which silently returns false because the Listing tab is not shown. This is unreachable on Forever, where both functions exist. `Q.Click` also gives no feedback when `ShowHint` returns false because the quest name is unreadable.
**Fix:** Drop the toggle fallback, or return false in that branch.

**Status: skipped.** Unreachable on Forever.

### IN-03: Dead `listingExtra` term in the Browse OnHide hook

**File:** `UI/InPlace.lua:322`
**Issue:** The hint hides on `LFGListingFrame` OnHide, which fires on every tab switch away from Listing, and that sets `listingExtra` to 0. So the term can only be non-zero if the hint is shown while Browse is shown, which `ShowHint` forbids. Browse `OnShow` still sets `WIDE` regardless, so there are no width jumps. This is harmless but misleading.
**Fix:** Keep it as a defensive measure and say so in a comment, or remove it.

**Status: fixed (c9389c7).** Removed; Browse's OnHide restores `baseWidth`.

### IN-04: Outline stays on the old button if the category list reorders

**File:** `QuestButton.lua:462-529`
**Issue:** The outline is parented to the button found at `ShowHint` or at `CategoryView` OnShow. If `LFGListingCategorySelection_UpdateCategoryButtons` reassigns `categoryID` to buttons while the hint is up, the outline sits on the wrong button until the next OnShow.
**Fix:** Call `PlaceOutline()` again from a `hooksecurefunc` on the update function, or accept the rare case.

**Status: skipped.** Rare case accepted.

---

_Reviewed: 2026-11-24_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
