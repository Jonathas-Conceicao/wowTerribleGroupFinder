---
phase: 03-rows-tooltip-and-own-listing
reviewed: 2026-11-11T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - Core.lua
  - Listings.lua
  - Preview.lua
  - UI/InPlace.lua
  - UI/MainFrame.lua
  - UI/Table.lua
  - UI/Widgets.lua
  - CLAUDE.md
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-11-11
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

The phase 3 diff (`a346c10..HEAD`) was read in full and checked against the forever branch of the Blizzard source. No blockers.

- **Taint:** nothing writes to Blizzard frames. The delist calls `C_LFGList.RemoveListing()`, which Forever's minimap menu also calls directly. It does not call `LFGListingFrame:RemoveListing`, `LFGBrowse_DoSearch`, `LFGParentFrameTab1_OnClick` or the stock tooltip functions.
- **Secret values:** the new `C_LFGList` reads (`GetSearchResultMemberCounts`, `GetSearchResultEncounterInfo`, `GetActivityGroupInfo`) are wrapped in `pcall` and checked for secrets. Number and string results are validated.
- **Format strings:** the user comment is only ever the argument to `format(LFG_LIST_COMMENT_FORMAT, ...)`, never the format.
- **Frame reuse:** every `FillRow` resets the new state (Discord icon and name width, slot positions and sizes, message/hide/delist visibility, comment colour).
- **Blizzard names:** `TANK_REMAINING`, `LFG_LIST_INDENT`, `VOICE_CHAT_MODE_FORMAT`, `LFG_LIST_TOOLTIP_MEMBERS` and `LFG_SELF_LISTING` match Blizzard's usage.

The remaining items are robustness and quality.

## Warnings

### WR-01: `W.IconButton` leaks an orphan button when the template loads but is unstyled

**File:** `UI/Widgets.lua:318-322`
**Issue:** `Create(...)` can succeed, for example via the no-template fallback inside `Create`. If `b.MiddleMiddle` is then nil, `b` is replaced by `W.Button(...)` and the first button stays parented to `parent` forever. In a pooled row that is one stray frame per row frame.
**Fix:** Hide and detach the discarded frame before replacing it:
```lua
if not styled then
	b:Hide()
	b:SetParent(nil)
	b = W.Button(parent, "", w, h)
end
```

### WR-02: Hide button tooltip callbacks assume the parent row always has a listing

**File:** `UI/Table.lua:884-891`
**Issue:** The title and body callbacks call `IsHidden(b:GetParent().listing)`. `IsHidden` (line 208) dereferences `l.leader.name`, so a row frame whose `listing` is nil (a pooled frame that was never filled, or one released mid-update) throws a Lua error on `OnEnter`. `ShowTooltip` guards `row.listing` for this reason, so the callbacks are inconsistent with it.
**Fix:**
```lua
local function RowHidden(b)
	local l = b:GetParent().listing
	return l ~= nil and IsHidden(l)
end
```
Use `RowHidden(b)` in both callbacks.

### WR-03: `Instance:Delist` does not re-check that the player may unlist

**File:** `UI/Table.lua:668-684`
**Issue:** The button is only shown when `CanUnlist(self)` is true (`FillRow`), but the handler itself only checks `HasActiveEntryInfo`. A grouped non-leader can reach it if the button state is stale: group roster changes do not necessarily trigger a refill before a click. `RemoveListing` would then be attempted for a listing the player does not own.
**Fix:** Add `if not CanUnlist(self) then return end` after the preview branch, before the `C_LFGList` calls.

## Info

### IN-01: Hide tooltip text names a button that may not be shown

**File:** `UI/Table.lua:1092-1100`, `UI/Table.lua:~1620` (hint line in `ExtrasTooltip`)
**Issue:** The row tooltip says "use the eye button to show", but when the atlases or the template are missing the button reads "+" or "x". `socialqueuing-icon-eye` also does not appear in the Blizzard source tree, so the fallback may be the common case.
**Fix:** Word the hint without naming the icon, for example "Hidden until they make a new listing (use the hide button to show)."

### IN-02: `VoiceLabels()` rebuilds a table on every tooltip

**File:** `UI/Table.lua:372-380`
**Issue:** A fresh four-entry table is built per `StockTooltip` call, and again on every refresh while a tooltip is hovered. This is harmless but unnecessary. The globals could be missing at file load but exist at call time, so build it lazily once.
**Fix:** Cache the table in an upvalue on first use.

### IN-03: `Refresh` computes `HoveredRow()` before the visibility early-return

**File:** `UI/Table.lua:1222-1225`
**Issue:** `hovered` is computed (iterating all frames) before the `band:IsVisible()` check, which returns without using it.
**Fix:** Move the `HoveredRow()` call below the visibility guard. The ScrollBox has not been re-filled at that point, so the value is still valid.

---

_Reviewed: 2026-11-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
