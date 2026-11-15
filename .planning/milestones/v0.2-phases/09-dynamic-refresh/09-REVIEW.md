---
phase: 09-dynamic-refresh
reviewed: 2026-11-14T13:38:32Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - UI/Motion.lua
  - UI/InPlace.lua
  - UI/Table.lua
  - UI/MainFrame.lua
  - Preview.lua
  - Listings.lua
  - Core.lua
  - ItemLevelUI.lua
  - TerribleGroupFinder.toc
findings:
  critical: 1
  warning: 7
  info: 5
  total: 13
status: issues_found
fixed_at: 2026-11-14
fix_status: partial
fixed: [CR-01, WR-01, WR-02, WR-03, WR-04, WR-05, WR-06, WR-07, IN-01, IN-02, IN-03, IN-04]
partly_fixed: [IN-05]
fix_commits: [7484fc3, 7de7796, 51e2895, 7c1d0ce, d1d833c]
---

# Phase 09: Code Review Report

**Reviewed:** 2026-11-14T13:38:32Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Scope: `git diff 8995188..HEAD`. That covers ns.Motion (swipe out/in, slide, Cancel, Busy), the Dynamic refresh gates in `UI/InPlace.lua`, the pooled-frame resets in `UI/Table.lua`, the preview's Churn/Refresh/reset, and the rewritten character sheet row. Blizzard's `forever` branch was used to check the call sites: `LFGBrowse_DoSearch` callers, ScrollBoxListView `ForEachFrame` / `SetDataProvider`, and the Camelot `CharacterStatsPaneScrollBoxTemplate`.

The Motion core holds up. Token and `pending` handling make stale timers harmless. The ScrollBox resetter plus the key check in FillRow/FillHeader cover released and re-used frames on the ScrollBox path. The character sheet row no longer writes Blizzard data.

The main problems are where Motion meets the read flow:
- A delisted listing that the merge drops and swipes out comes straight back on the next plain read. The deferred read that Motion itself schedules is enough to bring it back.
- `OnSearch` resets `readAfterSwipe` after `Motion.Cancel()` has already acted on it.
- `shownFilter` is updated on every `LFGBrowse_DoSearch` call, including the ones Blizzard turns into no-ops, so a double call becomes a false "same filter" refresh.
- The Busy guard covers clicks on rows, but not the list redraws from sorting, collapsing a section, the search box or Needs my role.
- The `W.List` fallback leaves a hidden row frame at alpha 0.
- The preview does not reproduce the game's delisted handling.
- The character sheet installer lost its PLAYER_LOGIN retry.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Swiped-out delisted listings pop back on the next plain read (often immediately after the swipe)

**File:** `Listings.lua:248-271`, `UI/InPlace.lua:111-139`
**Issue:** A merge read (`ns.Listings.Read(previous)`) drops delisted listings, so `Motion.Show` treats them as "went" and swipes them out. The client's search results still contain those listings, though (`isDelisted = true`). Every later read without a snapshot (`Listings.Read(nil)`) adds them back as greyed rows, with no animation. Those reads come from:
- `LFG_LIST_SEARCH_RESULT_UPDATED`
- `GROUP_ROSTER_UPDATE`
- `LFG_LIST_ACTIVE_ENTRY_UPDATE`
- Browse `OnShow` → `Read()`
- `/tgf` → `Read()`
- the deferred `AfterMotion` → `ReadSoon()` read

The deferred read alone is enough. After a search, `LFG_LIST_SEARCH_RESULT_UPDATED` events arrive in a burst, so one usually lands during the 0.4 s swipe-out, which sets `readAfterSwipe = true`. Right after the list updates, `AfterMotion` runs a plain read and the delisted rows come back.

The feature promises "vanished or delisted ones swipe out and leave" (CLAUDE.md, InPlace header). In practice they swipe out and then reappear. The drop also conflicts with the project rule "Never remove a listing from view: … delisted … greyed and moved to the end of their section". One of the two behaviours has to be chosen and applied on every read path.
**Fix:** Pick one rule.
- To keep the project rule, stop dropping delisted listings in `L.Read(previous)`. They then stay greyed and slide to the end, with no swipe.
- To keep "delisted leaves", remember the keys the merge dropped and filter them on plain reads until the next search, for example:
```lua
-- Listings.lua
L.dropped = {}
function L.Read(previous)
	...
	if previous then
		wipe(L.dropped)
	end
	for i = #items, 1, -1 do
		local l = items[i]
		if not l.mine and l.delisted and (previous or L.dropped[L.Key(l)]) then
			L.dropped[L.Key(l)] = true
			table.remove(items, i)
		elseif previous and not l.mine then
			local old = previous[L.Key(l)]
			if old then Carry(old.id, l.id) end
		end
	end
	return items
end
-- and wipe(L.dropped) in OnSearch when the search is not "same"
```
Then update the CLAUDE.md model rule to match.

## Warnings

### WR-01: OnSearch clears `readAfterSwipe` after `Motion.Cancel()` has already consumed it, so the stale deferred read still runs

**File:** `UI/InPlace.lua:82-83`
**Issue:** The comment says that after a cancel, "a read of the old answer deferred by it no longer runs". But `ns.Motion.Cancel()` calls `pending(false)` → `Update` → `after()` = `AfterMotion` synchronously. `AfterMotion` sees `readAfterSwipe == true` and calls `ReadSoon()`, which schedules `Read` 0.2 s later. Only after that does line 83 set `readAfterSwipe = false`, which does nothing.
- On a "same" search, `refresh.pending` makes that read return early, so no harm.
- On a new search, `Read` runs `ns.Listings.Read(nil)` against whatever `GetSearchResults` holds while the new search is in flight. It replaces `ns.Listings.items` with the old filter's results, which the following refresh-detection logic then relies on (`#ns.Listings.items > 0`).
**Fix:** Clear the flag before cancelling:
```lua
readAfterSwipe = false
ns.Motion.Cancel()
```

### WR-02: `shownFilter` updates on every `LFGBrowse_DoSearch` call, so Blizzard's double calls turn a new search into a "same" refresh

**File:** `UI/InPlace.lua:89-107`
**Issue:** `LFGBrowse_DoSearch` is a no-op while `LFGBrowseFrame.searching` is true (Blizzard_LFGVanilla_Browse.lua:331-333), but the post-hook runs every time. `LFGBrowseMixin:SearchActiveEntry` (line 233; called after listing via `LFGParentFrame_SearchActiveEntry`) and `ShowSearchForActivities` (line 247) both call `SetSelectedSearchActivities`, which calls `DoSearch`, and then call `DoSearch` again.
- First hook call: the key K2 differs from K1, so `shownFilter = K2` and the selection is cleared. The spinner is due.
- Second hook call, same tick: `key == shownFilter`, and `#ns.Listings.items > 0` still counts K1's results. So `same = true` and `refresh.pending = true`, which hides the spinner (`not refresh.pending`).

The result: the old activities' list stays on screen under the new dropdown until the answer. Then everything is merged against a K1 snapshot: all old rows swipe out, all new ones swipe in, and delisted ones are dropped (CR-01). With dynamicRefresh on, this is not stock behaviour for a new search.
**Fix:** Only treat a call as a refresh when Blizzard actually started a search from this call, and record the filter when the answer is read:
```lua
local function OnSearch()
	...
	local key = FilterKey()
	if refresh.issuedKey == key and LFGBrowseFrame.searching and refresh.issuedAt == GetTime() then
		return -- a repeat call in the same frame: Blizzard did nothing
	end
	refresh.issuedKey, refresh.issuedAt = key, GetTime()
	local same = key ~= nil and key == shownFilter and ...
	-- set shownFilter = refresh.issuedKey in the LFG_LIST_SEARCH_RESULTS_RECEIVED branch instead of here
```

### WR-03: The Busy guard covers clicks on rows, but not the list redraws from sorting, collapsing, the search box or Needs my role

**File:** `UI/Table.lua:1148`, `UI/Table.lua:1773`, `UI/Table.lua:1796` (column header sort handlers likewise); `UI/Motion.lua:175-193`
**Issue:** During the swipe-out the data source already holds the new listings, because in game `ns.Listings.Read` ran before `Motion.Show`; in the preview, Churn ran first. Any `RefreshAll` during that 0.4 s draws the new list immediately. The triggers include:
- section collapse (1148)
- Needs my role (1773)
- typing in the search box (1796)
- a column sort
- settings or region redraws

When the timer fires, `Update(true)` compares positions against `tops`, which were recorded before that redraw. Rows that have already moved jump back to their old offset and slide again, and rows that were already drawn in their new place get a fresh swipe-in. Busy also keeps blocking clicks on rows that now show the new results. This contradicts the Motion header's statement that "rows still hold the old results".
**Fix:** Do one of these:
- Make `Instance:Refresh` defer while `ns.Motion.Busy()` (set a `dirty` flag and redraw in `Update`).
- In these handlers, call `ns.Motion.Cancel()` first, so the list shows its final state with no slide:
```lua
-- at the top of each view-changing handler
ns.Motion.Cancel()
```

### WR-04: `W.List` fallback leaves hidden pooled frames at alpha 0 with their old motion key, so the row can come back invisible

**File:** `UI/Widgets.lua:756-760` (`pool[i]:Hide()` with no reset), `UI/Table.lua:1215-1219`
**Issue:** The reset for re-used frames is skipped when `row.tgfMotionKey == mkey`. On the ScrollBox path, released frames go through the resetter and get `tgfMotionKey = nil`. The `W.List` fallback has no resetter: when the list shrinks after a swipe-out, it only `Hide()`s the surplus frames. Those frames keep `tgfMotionKey = K` and alpha 0, because `SetToFinalAlpha(true)` leaves the alpha at 0.

Later, the same listing key K can return:
- the preview re-adds the same table from the reserve via Churn;
- in game, a player relists.

If K lands in that same pooled frame, FillRow skips `ResetRow`, and the row draws at alpha 0. With a swipe-in, `SetToFinalAlpha(false)` returns the frame to its own alpha of 0 when the animation ends, so the row is still invisible. The web simulator probably runs this fallback.
**Fix:** Reset surplus frames when `W.List` hides them, or give `W.List` a reset hook:
```lua
for i = (taken[kind] or 0) + 1, #pool do
	if ns.Motion then ns.Motion.ResetRow(pool[i]) end
	pool[i].tgfMotionKey = nil
	pool[i]:Hide()
end
```

### WR-05: The preview's delisted handling does not follow the game's path it is meant to simulate

**File:** `Preview.lua:465-475`, `Preview.lua:484-496`
**Issue:** `P.Refresh` is documented as "the same path as the game's Dynamic refresh through ns.Motion.Show". In game, a listing that comes back delisted on a refresh is dropped and swipes out (`Listings.Read(previous)`). Churn instead sets `delisted = true` and leaves the listing in `state.listings`. `Motion.Keys` still counts it, so it never appears in `went`: it just greys and slides to the end. The preview therefore never exercises the delisted swipe-out (or the bug in CR-01).
**Fix:** After CR-01's decision, make Churn match it. If delisted listings should leave, remove the delisted listing from `shownKeys`-based `now` (for example `Motion.Keys` skips `l.delisted` when the source is a merge), or have Churn move it out as the game does. If delisted listings should stay greyed, update the InPlace and CLAUDE.md wording instead.

### WR-06: In-game `/tgf preview` churns on every `LFGBrowse_DoSearch` call, including Blizzard's no-op double calls

**File:** `UI/InPlace.lua:84-88`
**Issue:** The hook runs `ns.Preview.Refresh()` for every `LFGBrowse_DoSearch` call. Besides the refresh button, those calls include:
- category and activity dropdown changes
- the activity reset button
- the delist button
- `SearchActiveEntry` and `ShowSearchForActivities`, which each call it twice

Each call removes and adds 1-3 listings, may delist one, and relists a hidden player, which prints a chat line. The second call of a pair also cancels the first one's swipe-out. Only the refresh button is meant to run the simulated refresh.
**Fix:** Gate the preview path to a real refresh: the same filter as before, or a hook on `LFGBrowseFrame.RefreshButton` with `HookScript("OnClick")`. Ignore repeat calls in the same frame (see WR-02).

### WR-07: The character sheet installer no longer retries when the pane isn't defined yet at our load

**File:** `ItemLevelUI.lua:321-325`
**Issue:** The previous version said "Not defined yet at our load: one more try at login" and registered `PLAYER_LOGIN` to call `UI.Install("sheet", CharacterSheet)` again. The rewrite returns `false` right away when `CharacterStatsPaneScrollBox` is missing at `ADDON_LOADED`. If that happens, the spot is recorded as failed (`"missing"`) and never installs this session. The rewrite dropped a case that had been observed, apparently without saying so.
**Fix:** Bring back the one-shot retry:
```lua
if not (pane and pane.HookScript) then
	if not sheetRetried then
		sheetRetried = true
		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_LOGIN")
		f:SetScript("OnEvent", function(self)
			self:UnregisterAllEvents()
			UI.Install("sheet", CharacterSheet)
		end)
	end
	return false
end
```

## Info

### IN-01: Redundant preview check in OnSearch

**File:** `UI/InPlace.lua:89`
**Issue:** `not ns.UsingPreview() and FilterKey() or nil`: the preview case already returned at line 87.
**Fix:** `local key = FilterKey()`.

### IN-02: `readAfterSwipe` can stay set in the preview path

**File:** `Preview.lua:495`, `UI/InPlace.lua:123-125`
**Issue:** With `/tgf preview` in game, the real search's answer can reach `Read` during the preview's swipe-out and set `readAfterSwipe = true`. `P.Refresh` passes no `after`, so the flag stays set until the next `OnSearch`, or until it fires an unrelated extra read after a later in-game `Motion.Show`.
**Fix:** Pass a callback that clears the flag, or have `Motion.Show` always run a shared post-update hook.

### IN-03: Turning a setting off mid-flight is not honoured

**File:** `UI/Motion.lua:200-220`, `UI/InPlace.lua:90-93`
**Issue:** Neither `swipeAnimations` nor `dynamicRefresh` has an `OnChange` handler. Turning animations off during a swipe-out still runs `Update(true)` with slides and swipe-ins. Turning Dynamic refresh off while `refresh.pending` still merges the answer.
**Fix:** `ns.Settings.OnChange("swipeAnimations", ns.Motion.Cancel)`, and clear `refresh.pending` / `refresh.snapshot` when `dynamicRefresh` turns off.

### IN-04: Swipe-in may draw one frame at full alpha before the fade starts

**File:** `UI/Motion.lua:78-101`
**Issue:** The Alpha animation is in order 2. During the order-1 zero-duration shift, the frame renders at its own alpha (1) at the +40 offset, which can show as a one-frame flash. Check this in game.
**Fix:** Add an order-1 `Alpha` (0 → 0, duration 0) for the swipe-in, or put the fade in order 1 with the shift.

### IN-05: The character sheet tooltip figure can differ from the row's figure; the row isn't drawn if the pane is already shown

**File:** `ItemLevelUI.lua:292-317`, `ItemLevelUI.lua:345`
**Issue:**
- The row shows `ILvl.Of("player")`, which is `max(GetMinItemLevel, floor(equipped))`. The tooltip's "Equipped" line shows raw `equipped`, so the two can disagree when the minimum item level applies.
- `UpdateSheet` is only hooked to `OnShow` and events. If the pane is already visible when the installer runs (for example after a retry, WR-07), the row stays hidden until a gear change.
**Fix:** Say in the tooltip which figure the row uses. Call `UpdateSheet()` once at the end of `CharacterSheet()`.

## Fix Notes

Applied 2026-11-14. Smoke harness: default, `--fallback` and `--attach` each `SUMMARY: 0 failed`, with new checks for CR-01, WR-01..WR-07 and IN-03. The harness's `LFGBrowse_DoSearch` stub now behaves like Blizzard's: it searches only while not already searching, and only when a category is set. Its answer helpers clear `searching`.

- **CR-01: fixed** (7484fc3; CLAUDE.md d1d833c). Author's rule: a Dynamic refresh drops the delisted listings in its answer. `Listings.lua` records their result IDs, and plain reads (`RESULT_UPDATED`, roster, Browse `OnShow`, the deferred read) leave those IDs out. Only delisted entries are filtered, so a relisted listing (live, under another ID) shows. The record is rebuilt on every merge and cleared by `ns.Listings.ClearDropped()` on a new search (another filter, or Dynamic refresh off). A listing that turns delisted between refreshes still shows greyed until the next refresh. The CLAUDE.md "Never remove a listing from view" bullet notes the exception.
- **WR-01: fixed** (7484fc3). `readAfterSwipe` is cleared before `Motion.Cancel()`.
- **WR-02: fixed** (7484fc3). `InPlace` mirrors Blizzard's `searching` flag. The hook sets it when it sees `LFGBrowseFrame.searching` true after a call it hadn't seen a search for, and the answer events clear it. A call made while a search is out started nothing, so it is ignored: no cancel, no selection clear, no refresh decision. A call that searched nothing (no category) is ignored too. `shownFilter` is now set when the search answers, to the filter it was issued with. A failed new search leaves no filter; a failed refresh keeps its filter. Blizzard's double calls and clicks during a search can no longer turn a new search into a refresh against an old snapshot.
- **WR-03: fixed** (7de7796). `Instance:Refresh` cancels a running swipe-out first. Any redraw during it (sort, collapse, search box, Needs my role, a setting, a region redraw) shows the new list at once, with no slide, and the rows are at rest.
- **WR-04: fixed** (7de7796). `W.List` resets the frames it hides (`Motion.ResetRow`, `tgfMotionKey = nil`).
- **WR-05: fixed** (51e2895). The preview's Dynamic refresh moves shown delisted listings back to the reserve, live (`P.DropDelisted`), so they swipe out as in game. `P.Churn` no longer delists. `P.DelistOne` turns one listing delisted about one time in three: 1.5 s after the update on a Dynamic refresh (as between the game's refreshes), or right away on a stock one. A Dynamic refresh also ends a stock-mode spinner that is still showing.
- **WR-06: fixed** (7484fc3). With `/tgf preview` in game, only a search of the same filter again (the refresh button) churns. Any other search is a new list of the preview data (the selection is cleared). Calls made while Blizzard is searching do nothing (WR-02).
- **WR-07: fixed** (7c1d0ce). The one-shot `PLAYER_LOGIN` retry is back (queued once). The row is drawn at install when the pane is already visible (pcall'd, so a failing lookup doesn't mark the installer failed).
- **IN-01: fixed** (7484fc3). Plain `FilterKey()`.
- **IN-02: fixed** (7484fc3). `Motion.OnUpdated(fn)` runs after every Show's update. InPlace registers its deferred read there, so the preview's Show also runs it.
- **IN-03: fixed** (7484fc3). Turning `swipeAnimations` off cancels a swipe-out. Turning `dynamicRefresh` off while a refresh is out drops the refresh state, so the spinner shows and the answer is a plain read.
- **IN-04: fixed** (7484fc3). An order-1, zero-duration Alpha (0 → 0 when swiping in, 1 → 1 when swiping out) sets the starting alpha before the move. Still to be checked in game.
- **IN-05: partly fixed** (7c1d0ce). The row is now drawn at install when the pane shows. Not changed: the tooltip wording for when the minimum item level raises the row's figure above "Equipped". That is a wording choice for the author.

---

_Reviewed: 2026-11-14T13:38:32Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
