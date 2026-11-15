---
phase: 02-list-foundation
reviewed: 2026-11-11T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - UI/Table.lua
  - UI/Widgets.lua
  - UI/InPlace.lua
  - UI/MainFrame.lua
  - UI/Listing.lua
  - UI/Templates.xml
  - TerribleGroupFinder.toc
findings:
  critical: 0
  warning: 12
  info: 5
  total: 17
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-11-11
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Narrative Findings (AI reviewer)

## Summary

I reviewed the phase-2 diff (`80e2737..HEAD`) for `UI/` and the TOC against CLAUDE.md, `02-CONTEXT.md`, and Blizzard's source (branch `forever`, read only).

**What checks out:**
- **Taint:** no taint path found.
  - `LFGBrowseSearchEntryGroupingTemplate` has no scripts and no mixin (`Mainline/Blizzard_LFGVanilla_Browse.xml:277`).
  - `ColumnDisplayButtonShortTemplate` has no scripts.
  - Blizzard's frames are only read (`searching`, `searchFailed`, `RefreshButton`) or used as anchors.
  - `LFGBrowse_DoSearch` sets `searching = true` before the hook runs, so the spinner shows correctly.
- **ScrollBox calls:** all exist on this branch and are used correctly: `SetElementResetter`, `SetElementExtentCalculator`, `RetainScrollPosition`, `RemoveDataProvider`, `ReinitializeFrames`, and the `OnVisibilityChanged` payload `(owner, visible)`.
- **Factory purity:** the factory is pure (one `Init` closure, chosen by item kind).
- **Extents:** the extents match the template sizes.
- **Pooled frames:** these are reset on every fill: icon size, desaturation, slots, cell alpha and colours.
- **Sort arrow:** the texcoords match D-15 and AuctionHouse.

**Issues:**
- **Selection lifecycle:**
  - A dropped selection still draws as selected (WR-01).
  - The selection can act on a row you can't see (WR-03).
- **Failed-search state:** the list keeps its old rows under the failure text (WR-02).
- **Preview and fallback layout:** BarTop/BarMiddle are invisible (WR-04), and the fallback list doesn't line up with the header (WR-06).
- **Header alignment:** the Listed label sits 4 px too far right (WR-05).
- **Greyed text:** some text keeps its colour codes (WR-08).
- **Pre-existing code** that this phase touches or depends on: WR-09 to WR-12.

No findings are Critical. Nothing found crashes, taints Blizzard's frames, or loses data with the current flags. I did not test whether `C_LFGList.RemoveListing` is restricted when called from addon code (WR-11).

## Warnings

### WR-01: A dropped selection still draws as selected (rows filled before `RefreshButtons` clears the ID)

**File:** `UI/Table.lua:892` (SetItems), `UI/Table.lua:913` (RefreshButtons), `UI/Table.lua:811`, `UI/Table.lua:918-925`
**Issue:** `Refresh()` calls `self.list:SetItems(self.items)` first, so `FillRow` runs `row.selected:SetShown(IsSelected(self, l))` against the old `selectedID`. `RefreshButtons()` runs only afterwards, and that is where the selection is dropped when the listing is gone or delisted (D-10).

When the selected listing turns delisted after a read:
- the greyed, unclickable row keeps the gold `mid2-selected` overlay;
- Send Message / Group Invite are already disabled.

The overlay stays until something else re-fills the frames. The row and the buttons disagree, and the user sees a selected row they can't act on or deselect, because `OnClick` returns early for delisted rows.
**Fix:** validate the selection before filling the rows:
```lua
local solo, groups = self:Collect()
local sel = FindByID(self, self.selectedID)
if self.selectedID and (not sel or sel.delisted) then
	self.selectedID = nil
end
self.list:SetItems(self.items)
...
self:RefreshButtons()
```
Or split `RefreshButtons` into `ValidateSelection()` (called before `SetItems`) and the enable logic.

### WR-02: A failed search keeps the old rows under the "Search failed." text

**File:** `UI/Table.lua:889-907`
**Issue:** When `source.failed()` is true, `Refresh` still runs `Collect()` and `SetItems(self.items)`, then writes `LFG_LIST_SEARCH_FAILED` into `stateText`. `stateText` sits at art TOP -40, on top of the first row.

Stock behaves differently. `LFGBrowseMixin:UpdateResults` (`Blizzard_LFGVanilla_Browse.lua:186-196`) calls `RemoveDataProvider()` and shows only `NoResultsFound` when `searchFailed`.

Whatever `GetFilteredSearchResults()` still returns after a failure (the previous search's results, or a re-read of them) is drawn under the failure text. Those rows can still be selected, and whispered or invited.
**Fix:**
```lua
if self.source.failed and self.source.failed() then
	self.list:Clear()
	self.selectedID = nil
	self.stateText:SetText(LFG_LIST_SEARCH_FAILED or "Search failed.")
	self.status:SetText("")
	self:RefreshButtons()
	return
end
```

### WR-03: Send Message / Group Invite can act on a listing you can't see

**File:** `UI/Table.lua:415-418`, `UI/Table.lua:826-829`, `UI/Table.lua:1180-1186`
**Issue:** `byID` is filled from every listing, before `Matches()` and before the collapse check. Its comment says so: "folded away or filtered out ones too". `RefreshButtons` keeps the selection as long as the ID exists.

So you can:
1. select a row;
2. type in the search box so it no longer matches, or fold its section;
3. press Send Message (whispers that player) or Group Invite (invites them).

The listing being acted on is not on screen, and nothing tells you a selection still exists. D-09 says the selection survives re-sorts, hides and re-reads. It does not say it survives being filtered out of view.
**Fix:** only index listings that `Collect` puts into `items`. Or have `RefreshButtons` also require the listing to be visible:
```lua
-- in Collect, after deciding to emit l:
self.visibleIDs[l.id] = true
-- in RefreshButtons:
if self.selectedID and (not sel or sel.delisted or not self.visibleIDs[self.selectedID]) then
```
If keeping hidden selections is intended, at least disable the buttons while the selected row is not shown.

### WR-04: The stand-in's BarTop / BarMiddle lines have zero height wherever the atlas exists

**File:** `UI/MainFrame.lua:253-266`
**Issue:** `W.Atlas` calls `tex:SetAtlas(atlas)` without `useAtlasSize`. `SetHeight(1)` runs only in the fallback branch.

When `groupfinder-ScrollLine` exists, the texture has only LEFT/RIGHT anchors and no height, so it is 0 px tall and invisible. Stock uses `useAtlasSize="true"` (`Mainline/Blizzard_LFGVanilla_Browse.xml` BarTop/BarMiddle). The preview, with atlases, therefore loses both lines that D-13 says it must mirror.
**Fix:**
```lua
local barTop = art:CreateTexture(nil, "OVERLAY")
if W.HasAtlas("groupfinder-ScrollLine") then
	barTop:SetAtlas("groupfinder-ScrollLine", true)
else
	barTop:SetColorTexture(0.35, 0.3, 0.2, 0.8)
	barTop:SetHeight(1)
end
```
Do the same for `barMiddle`.

### WR-05: The "Listed" header label is pushed 4 px outside its button, and its sort arrow lands past the column

**File:** `UI/Table.lua:1126`, `UI/Table.lua:1138-1139`
**Issue:** The x offset is `justify[key] == "CENTER" and 0 or 4`, so RIGHT-justified text gets **+4**:
- `SetPoint("RIGHT", b, "RIGHT", 4, 0)` puts the label 4 px past the button's right edge, out of line with the rows' `listed` text, which ends at the cell edge.
- The arrow is anchored to `text` RIGHT +3, so it lands about 7 to 17 px outside the Listed cell, over the buttons' column.

This breaks the "every cell width-bound" rule in CLAUDE.md for the header.
**Fix:**
```lua
local j = justify[key] or "LEFT"
local x = (j == "CENTER" and 0) or (j == "RIGHT" and -4) or 4
text:SetPoint(j, b, j, x, 0)
```
For RIGHT-justified columns, put the arrow on the text's LEFT (`arrow:SetPoint("RIGHT", text, "LEFT", -3, 0)`) so it stays inside the cell.

### WR-06: The fallback W.List rows don't line up with the header strip (right-side columns 8 px off)

**File:** `UI/Table.lua:1039-1040`, `UI/Widgets.lua:545`, `UI/Table.lua:1113-1118`
**Issue:** In the fallback path:
- The list's BOTTOMRIGHT is `back` -6, and `W.List` anchors every frame at `RIGHT, list, RIGHT, -8`, so rows end 14 px in from the area's right edge.
- The header strip is placed with `PlaceStrip(false)` at -6 and is never moved, because there is no visibility callback in this path.

Listed and Activity's right edge in the header are therefore 8 px right of the rows' cells. D-18 requires header and rows to stay aligned.
**Fix:** call `placeStrip` for the fallback with the offset it really uses. For example, return the list and call `PlaceStrip` with a custom inset (`-14`):
```lua
local function PlaceStrip(barShown, inset)
	header:SetPoint("TOPRIGHT", area, "TOPRIGHT", inset or (barShown and -22 or -6), 0)
end
-- fallback:
placeStrip(false, -14)
```
Alternatively, make W.List's frame inset (`-8`) a parameter and pass 0 here.

### WR-07: "Your GS" is anchored over the Needs my role label (latent; shows when `ns.GEAR_SCORE` is on)

**File:** `UI/Table.lua:1189-1194`
**Issue:** `status` spans from `fits.Label` RIGHT to `invite` LEFT, and its text is right-justified inside that span. `myGS` is anchored `RIGHT` to `status` **LEFT** -12, so it ends 12 px left of the end of the "Needs my role" label and is drawn over it.

This is hidden today only because `ns.GEAR_SCORE = false` (`Core.lua:17`). It was introduced this phase: before, `myGS` was at `RIGHT -4` of the host.
**Fix:** give `status` a single RIGHT anchor and anchor `myGS` to the visible text's left. Alternatively, anchor `myGS` LEFT to `fits.Label` RIGHT +8 and `status` LEFT to `myGS` RIGHT +12:
```lua
self.status:SetPoint("RIGHT", self.invite, "LEFT", -8, 0)
if self.myGS then
	self.myGS:SetPoint("LEFT", self.fits.Label, "RIGHT", 12, 0)
	self.status:SetPoint("LEFT", self.myGS, "RIGHT", 8, 0)
else
	self.status:SetPoint("LEFT", self.fits.Label, "RIGHT", 8, 0)
end
```

### WR-08: Greyed rows keep coloured fragments (activity "+N", name tags), against D-22

**File:** `UI/Table.lua:262-264`, `UI/Table.lua:752`, `UI/Table.lua:768`
**Issue:** D-22 says all of a greyed row's text is drawn in `{0.3,0.3,0.3}`. `Plain()` is applied to GS and count only.

These keep their colour codes on greyed rows:
- `ActivityText` embeds `|cff999999+N|r` in the activity cell, so on a greyed row "+N" is brighter than the text around it.
- The name line's fallback tags (`W.Icon` / `W.Marks`: `|cff66ccffnew|r`, `|cff96ff82friend|r`, …) stay coloured.
- With atlases, the inline `|A` icons are not desaturated.

So "greyed" rows show bright fragments.
**Fix:** `row.activity:SetText(greyed and Plain(ActivityText(l)) or ActivityText(l))`. Build the name line, then `row.name:SetText(greyed and Plain(nameText) or nameText)`.

### WR-09: The search box's text insets cover SearchBoxTemplate's magnifier and clear button (pre-existing)

**File:** `UI/Widgets.lua:327` (used by `UI/Table.lua:1076`)
**Issue:** `W.EditBox` always calls `e:SetTextInsets(2, 2, 0, 0)`. `SearchBoxTemplate` sets `<TextInsets left="16" right="20"/>` (`InputBoxTemplates.xml:247`), so the magnifier and the clear button have room.

Overriding the insets draws typed text and the "Name, activity or note" instructions on top of the magnifier icon. Long input also runs under the clear (x) button. This code predates the phase, but D-14 relies on it for the native look.
**Fix:** only set insets on the fallback / `InputBoxTemplate` path:
```lua
if template ~= "SearchBoxTemplate" or not e.searchIcon then
	e:SetTextInsets(2, 2, 0, 0)
end
```

### WR-10: The `pcall` around the comment search does not cover `lower()` (pre-existing)

**File:** `UI/Table.lua:179-184`
**Issue:** In `pcall(find, lower(l.comment), text, 1, true)`, `lower(l.comment)` is evaluated **before** `pcall` is entered, so the guard protects only `find`.

`Listings.lua:150` says "The comment … may not support string work, so it is not searched", yet `Table.Matches` does search it. If `lower` raises on such a value:
- `Refresh` throws on every keystroke in the search box while any listing has a comment;
- the table stops updating.
**Fix:** either honour Listings' decision and drop the comment from `Matches`, or move the whole operation inside the guard:
```lua
local ok, hit = pcall(function(c) return find(lower(c), text, 1, true) end, l.comment)
```

### WR-11: Unlist calls `C_LFGList.RemoveListing()` directly, for any listing that contains you (pre-existing)

**File:** `UI/Table.lua:440-446`, `UI/Table.lua:814` (Unlist button label/enable); origin `Listings.lua:155`
**Issue:**
- **Taint / stock state.** CLAUDE.md says "Listing (create/update/unlist) stays Blizzard's own tab". Stock delists through `LFGListingFrame:RemoveListing()`, which first sets `PENDING_LISTING_UPDATE = true` (`Blizzard_LFGVanilla_Listing.lua:330-333`). The stock Browse delist button also re-searches and switches tabs (`Blizzard_LFGVanilla_Browse.lua:1295-1301`). Our call skips the pending flag, so Blizzard's Listing tab can miss the change.
- **Wrong rows.** `l.mine` is `info.hasSelf`, which is true for every member of a listed group. A non-leader therefore gets an enabled "Unlist" button that calls `RemoveListing`. Stock shows its delist button only when `not IsInGroup() or UnitIsGroupLeader("player")` (`Blizzard_LFGVanilla_Browse.lua:916`).
**Fix:** enable Unlist only when `not IsInGroup() or UnitIsGroupLeader("player")`. Route the unlist through Blizzard's own UI: open the Listing tab, or click its existing control. Do not call the API directly from our table. If the direct call stays, confirm in game that it is not blocked and that the Listing tab refreshes afterwards.

### WR-12: Group Invite uses `fullName`, against the plain-name rule in CLAUDE.md (pre-existing)

**File:** `UI/Table.lua:462`
**Issue:** `C_PartyInfo.InviteUnit(l.leader.fullName or l.leader.name)`. CLAUDE.md says: "whisper and invite by plain character name, without a realm suffix". `Listings.lua:32-33` stores `name` as `shortName` (or the full name) and keeps the raw `info.fullName` separately. Wherever `fullName` carries a realm suffix, this invite violates the project's realm rule.
**Fix:** `C_PartyInfo.InviteUnit(l.leader.name)`.

## Info

### IN-01: `local view` in `BuildList` shadows the module's sort/filter state `view`

**File:** `UI/Table.lua:961`
**Issue:** Inside the ScrollBox branch, `view` now means the ScrollBox view. Nothing in that block reads `view.collapsed`, `view.sort` and so on today, but a later edit that does would silently hit the wrong table.
**Fix:** rename it to `scrollView` (or rename the module state to `state`).

### IN-02: Dead or duplicate code

**File:** `UI/Table.lua:1004-1006`, `UI/Widgets.lua:575-579`, `UI/Widgets.lua:222-229`, `UI/Table.lua:717-719`
**Issue:**
- `host:ForEachFrame` and `list:ForEachFrame` have no callers.
- `W.Line` has no callers since the per-row line was removed.
- `row.item` and `row.listing` hold the same table.
**Fix:** remove the unused helpers, and keep one field on the row.

### IN-03: Showing Browse runs Refresh three times

**File:** `UI/InPlace.lua:177-181`, `UI/InPlace.lua:200-205`, `UI/Table.lua:1210-1212`, `UI/MainFrame.lua:93-98`
**Issue:**
- On show: `ClearSelection()` triggers `RefreshAll()`, then `Read()` triggers `Refresh()`, and the band's `OnShow` triggers `Refresh()` again.
- On `RESULTS_RECEIVED`: an immediate refresh on stale data, then another after `ReadSoon`.

Each refresh rebuilds the data provider. The result is correct, but the work is wasted.
**Fix:** have `ClearSelection` only clear the IDs (or take a `noRefresh` flag) when a refresh follows anyway.

### IN-04: The status line is stale while searching; the empty-search text overlaps your own row

**File:** `UI/Table.lua:882-888`, `UI/Table.lua:1201`
**Issue:**
- The searching branch returns before `self.status` is updated, so "N solo players, M groups" from the previous results stays next to the spinner.
- The "No listings match your search." text (art TOP -40) is drawn over your own listing row, which still shows at about -26 to -66. D-27 accepts the text with the own row present, but not the overlap.
**Fix:** clear `self.status` in the searching branch. When `items[1]` is your own listing, move `stateText` below that row.

### IN-05: Header labels on the template path aren't width-bound

**File:** `UI/Table.lua:1125-1127`
**Issue:** With `ColumnDisplayButtonShortTemplate`, `text` gets one anchor and no width, so a longer localised label would spill past its column. This goes against the CLAUDE.md layout guard ("every cell width-bound").
**Fix:** anchor the text on both sides (`SetPoint("LEFT", 4, 0)` plus `SetPoint("RIGHT", -4, 0)`) and keep `SetJustifyH`.

---

_Reviewed: 2026-11-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
