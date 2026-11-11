---
phase: 03-rows-tooltip-and-own-listing
reviewed: 2026-11-11T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - Core.lua
  - Listings.lua
  - Preview.lua
  - UI/InPlace.lua
  - UI/MainFrame.lua
  - UI/Table.lua
  - UI/Widgets.lua
findings:
  critical: 0
  warning: 1
  info: 3
  total: 4
status: issues_found
---

# Phase 3: Code Review Report (re-review)

**Reviewed:** 2026-11-11
**Depth:** standard
**Files Reviewed:** 7 (CLAUDE.md is documentation and was only read for conventions)
**Status:** issues_found

## Summary

Re-review of `git diff a346c10..HEAD` after the iteration-1 fixes (commits a0d6483, 650d3f4, 27dcd5e).

Verification of the previous findings:

- WR-01 (orphan button in `W.IconButton`): fixed. The unstyled button is hidden and detached before `W.Button` replaces it. A frame can never be released in WoW, so the orphan still exists, but it is invisible and no longer a child of the row (see IN-01).
- WR-02 (hide button tooltip with no listing): fixed. `RowHidden` is nil-safe and both callbacks use it. `W.Tooltip` handles function titles and bodies correctly, and a nil title returns before `SetOwner`.
- WR-03 (`Delist` re-check): fixed. The preview branch comes first, then `CanUnlist`, then the API presence and secret-value checks, then `C_LFGList.RemoveListing()`. The fix introduced no regression. The delist button is hidden whenever `CanUnlist` is false, so the early return is only a safety net.

Taint audit: nothing in the changed files calls `LFGBrowse_DoSearch`, `LFGParentFrameTab1_OnClick`, `LFGListingFrame:RemoveListing` or `LFGBrowseSearchEntryTooltip_UpdateAndShow`. The only references are the existing `hooksecurefunc("LFGBrowse_DoSearch", ...)` in `UI/InPlace.lua:203` and the preview print strings. No fields are written on Blizzard frames. `GameTooltip` is only owned by our own frames. The tooltip now reads `GetSearchResultMemberCounts`, `GetSearchResultEncounterInfo` and `GetActivityGroupInfo`. All three are `pcall`ed and checked with `type()` and `issecretvalue`.

Frame reuse, secret values and format strings looked sound:

- Frame reuse: `FillRow` resets size, atlas, colour, alpha and desaturation on every fill. `RoleIcon:SetRole` restores its size on every call. The discord, delist and hide parts are reset on every fill.
- Secret values: `Num()` and `Secret()` guard every new `Listings.lua` read.
- Format strings: every `format` call passes the user-controlled text (activity names, comments, player names) as an argument, never as the pattern.

One new issue was found (WR-01) plus three minor ones.

## Warnings

### WR-01: `BossNames` queries the real API with a preview listing's id

**File:** `UI/Table.lua:447-462` (called from `StockTooltip` at line 553)
**Issue:** `BossNames(l)` calls `C_LFGList.GetSearchResultEncounterInfo(l.id)` without checking whether the table is showing preview data. Preview listings have ids 1..n (`Preview.lua`, `Add`), and your own preview row has id 0. When the preview runs inside the real client (`ns.UsingPreview()` true with the game's API present, as `UI/InPlace.lua` allows), those small ids can collide with real search results. The tooltip then lists another listing's defeated bosses under a sample group, and a stale id can make the API throw. The `pcall` hides the throw, but the result is still wrong. The sample data never intends to show bosses.
**Fix:** Skip the lookup for preview data and for your own row, and pass the instance in:
```lua
local function BossNames(l, inst)
	if l.mine or (inst and inst.source.preview()) or #l.acts ~= 1
		or not (C_LFGList and C_LFGList.GetSearchResultEncounterInfo) then
		return nil
	end
	-- unchanged below
end
-- StockTooltip(tip, l, ids, inst): local bosses = BossNames(l, inst)
```
(`ShowTooltip` already has `inst`; pass it through to `StockTooltip`.)

## Info

### IN-01: `W.IconButton` creates a template button only to discard it

**File:** `UI/Widgets.lua:319-325`
**Issue:** The WR-01 fix hides and detaches the unstyled button, but the frame can never be freed and exists once per call. Each row creates two icon buttons, so the cost repeats for every pooled row on a client where the template is unstyled.
**Fix:** Probe once before creating, as `TemplateKnown` does in `Table.lua`. For example, cache the result of the first `Create(...).MiddleMiddle ~= nil` check in a module-level `local styledTemplate`, and skip the template path when it is false.

### IN-02: Local `view` shadows the module-level `view` table

**File:** `UI/Table.lua:1348`
**Issue:** Inside `BuildList`, `local view = CreateScrollBoxListLinearView()` shadows the shared filter and sort table `view` (line 87). It is harmless today because the block never reads `view.collapsed` or `view.sort`. A later edit to that block that uses `view.search` would read the scroll view instead.
**Fix:** Rename it to `scrollView`.

### IN-03: `Delist` plays the click sound before it checks whether it will act

**File:** `UI/Table.lua:665-675`
**Issue:** `W.PlayCheckbox(true)` runs first, so the early returns for `not CanUnlist`, a missing API and a secret value still play a sound for a click that does nothing. The delist button is hidden when the player cannot unlist, so this is rarely reachable.
**Fix:** Move `W.PlayCheckbox(true)` just before `C_LFGList.RemoveListing()` and into the preview branch.

---

_Reviewed: 2026-11-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
