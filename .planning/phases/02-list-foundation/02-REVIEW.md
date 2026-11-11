---
phase: 02-list-foundation
reviewed: 2026-11-11T17:32:19Z
depth: standard
iteration: 2
files_reviewed: 9
files_reviewed_list:
  - UI/Table.lua
  - UI/Widgets.lua
  - UI/InPlace.lua
  - UI/MainFrame.lua
  - UI/Listing.lua
  - UI/Templates.xml
  - TerribleGroupFinder.toc
  - Listings.lua
  - Messages.lua
findings:
  critical: 0
  warning: 1
  info: 9
  total: 10
  warning_resolved: 1
status: issues_found # info items only remain open; the one warning is resolved (acf7199)
---

# Phase 2: Code Review Report (iteration 2)

**Reviewed:** 2026-11-11T17:32:19Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Narrative Findings (AI reviewer)

## Summary

I re-reviewed the phase after the fix commits `f701163..b60696e` (diff `2bba090..HEAD`). I read every file in scope in full. Blizzard's source (branch `forever`, read only) was the reference.

**Iteration-1 fixes, checked one by one:**

| ID | Verdict | Notes |
|----|---------|-------|
| WR-01 | Fixed | `ValidateSelection()` now runs after `Collect()` and before `SetItems()` (`Table.lua:933-936`), so no row draws a dropped selection. |
| WR-02 | Fixed | The failed branch clears the list, the selection and the status, then returns (`Table.lua:924-931`). This matches stock `UpdateResults` (`Blizzard_LFGVanilla_Browse.lua:193-195`). |
| WR-03 | Fixed | `shownIDs` is filled only for rows that are emitted (`Table.lua:884-886`). The bottom buttons enable from `ShownSelection`, and act on it. Folding a section or filtering the row out disables them, and expanding or clearing the filter brings the selection back. |
| WR-04 | Fixed | `ScrollLine()` uses `SetAtlas(..., true)`. The fallback keeps a 1 px colour line. |
| WR-05 | Fixed on the template path | The RIGHT-justified label is now inset -4 and its arrow sits before the text. The non-template path still has the problem (IN-07). |
| WR-06 | Fixed | The fallback list ends at area -14 (list -6 plus W.List -8), and so does the header. The right-side columns line up on both: -97 = `ACTIONS_W + GAP`. |
| WR-07 | Fixed | The status has one RIGHT anchor. `myGS` takes the room after Needs my role. |
| WR-08 | Fixed | The greyed name and activity go through `Plain()`. The `|A` and `|T` markup is kept on purpose, as the fix report says. |
| WR-09 | Fixed | The `searchIcon` parentKey guard is correct for `SearchBoxTemplate`. |
| WR-10 | Fixed | `lower()` and `find()` both run inside the pcall'd closure. |
| WR-11 | Partly fixed | The Unlist gating now matches stock's rule (`Blizzard_LFGVanilla_Browse.lua:916`), and `Message()` checks it again. The direct `RemoveListing` call without `PENDING_LISTING_UPDATE` was deferred to Phase 3 (IN-06). |
| WR-12 | Fixed | Invite uses `l.leader.name`, which is `ns.Short(p.name)`. The follow-up `b60696e` does the same for whispers. |

**Regressions from the fixes:** none found.
- Selection: the click → `RefreshButtons` → `Reinitialize` path still works.
- `ValidateSelection` running twice in one refresh is harmless.
- Factory purity and pooled-frame resets are unchanged.
- No new writes to Blizzard frames.
- The searching and failed branches still reach `RefreshButtons`.

**Open issues:**
- One warning, in `Messages.lua`. It predates this loop, but the file is now in scope because of the `b60696e` follow-up.
- The iteration-1 Info items are all still open, carried as IN-01 to IN-05.
- Four new Info notes: IN-06 to IN-09.

## Warnings

### WR-01: Auto-send whispers during chat messaging lockdown, and marks the row "sent" before sending

**RESOLVED** in `acf7199` (fix loop iteration 2, see `02-REVIEW-FIX.md`).

**File:** `Messages.lua:103-113`
**Issue:**
- **No lockdown check.** With Auto-send on, `M.Send` calls `C_ChatInfo.SendChatMessage` / `SendChatMessage` without checking `C_ChatInfo.InChatMessagingLockdown()`. CLAUDE.md requires that check before an addon sends a message ("never send addon messages during `C_ChatInfo.InChatMessagingLockdown()`"). `Listings.Read` already applies the same guard (`Listings.lua:171`).
- **"sent" is set first.** `ns.state.messaged[l.id] = true` is set before the send, and whether or not the send happens. During lockdown the whisper is blocked or dropped, but the row's Listed cell still turns to "sent" (`Table.lua:802-803`). Nothing tells the user it didn't go out.

**Fix:** check for lockdown first, and record "sent" only after a send was attempted:
```lua
if auto then
	if preview then
		ns.state.messaged[l.id] = true
		return ns.Print(string.format("preview: whispered %s: %s", target, text))
	end
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
		-- Can't send now: fall through to the prefilled whisper box (sent with Enter).
	else
		if C_ChatInfo and C_ChatInfo.SendChatMessage then
			C_ChatInfo.SendChatMessage(text, "WHISPER", nil, target)
		else
			SendChatMessage(text, "WHISPER", nil, target)
		end
		ns.state.messaged[l.id] = true
		return
	end
end
```

## Info

### IN-01: `local view` in `BuildList` shadows the module's sort/filter state `view` (carried over)

**File:** `UI/Table.lua:1009`
**Issue:** This is still present. Inside the ScrollBox branch, `view` is the ScrollBox view, not the shared filter and sort state (`Table.lua:86`).
**Fix:** rename it to `scrollView`.

### IN-02: Dead or duplicate code (carried over)

**File:** `UI/Table.lua:1052-1054`, `UI/Widgets.lua:578-582`, `UI/Widgets.lua:222-229`, `UI/Table.lua:740-742`
**Issue:**
- `host:ForEachFrame` and `list:ForEachFrame` have no callers.
- `W.Line` has no callers.
- `row.item` and `row.listing` hold the same table.

**Fix:** remove the unused helpers, and keep one field on the row.

### IN-03: Showing Browse runs Refresh three times (carried over)

**File:** `UI/InPlace.lua:177-181`, `UI/InPlace.lua:200-205`, `UI/Table.lua:1270-1272`, `UI/MainFrame.lua:93-98`
**Issue:**
- On show: `ClearSelection()` refreshes, then `Read()` refreshes, then the band's `OnShow` refreshes again.
- On `RESULTS_RECEIVED`: one refresh runs on the previous read, and another runs after `ReadSoon`.

**Fix:** have `ClearSelection` only clear the IDs (or take a `noRefresh` flag) when a refresh follows anyway.

### IN-04: The searching branch leaves the status and button state from the previous results (carried over, extended)

**File:** `UI/Table.lua:915-921`, `UI/Table.lua:1261`
**Issue:**
- **Stale status.** The searching branch returns without clearing `self.status`, so "N solo players, M groups" stays next to the spinner. The failed branch now clears it (`Table.lua:928`), so the two branches no longer match.
- **Stale buttons.** The branch also calls `RefreshButtons()` against the previous `byID` and `shownIDs`, while the list has been cleared. In game, the `LFGBrowse_DoSearch` hook clears the selection first, so the stale state never reaches Send Message / Group Invite. Only that ordering keeps it safe.
- **Overlap.** The "No listings match your search." text (art TOP -40) still overlaps your own listing's row.

**Fix:** in the searching branch, add `self.status:SetText("")` and `wipe(self.shownIDs)` before `RefreshButtons()`. When `items[1]` is your own listing, move `stateText` below that row.

### IN-05: Header labels on the template path aren't width-bound (carried over)

**File:** `UI/Table.lua:1177-1181`
**Issue:** With `ColumnDisplayButtonShortTemplate`, the label still has a single anchor and no width. A longer localised label would spill past its column, against the CLAUDE.md layout guard. The CENTER `Lvl` column (30 px) is the tightest: its arrow at text RIGHT +3 already reaches into the 4 px gap before Roles.
**Fix:** anchor the text on both sides (LEFT +4 and RIGHT -4) and keep `SetJustifyH`.

### IN-06: Unlist still calls `C_LFGList.RemoveListing()` directly (WR-11 remainder, deferred to Phase 3 / UIP-08)

**File:** `UI/Table.lua:463-468`, `UI/Table.lua:445-450`
**Issue:**
- **Pending flag.** The enable rule is fixed. Two things are still left over, and both were deferred on purpose:
  - the call skips stock's `PENDING_LISTING_UPDATE = true` (`Blizzard_LFGVanilla_Listing.lua:330-333`);
  - it goes against CLAUDE.md's "Listing (create/update/unlist) stays Blizzard's own tab".
- **Duplicated check.** `CanUnlist` re-implements a group-role question in the table. By the architecture notes, `Core.lua` answers those (`ns.IsLeader` and `ns.CanInvite` sit there).

**Fix:** in Phase 3, route the unlist through `LFGListingFrame:RemoveListing()` or the stock delist control. Move the rule to `Core.lua`, as `ns.CanUnlist()`.

### IN-07: The fallback header path (no `ColumnDisplayButtonShortTemplate`) still draws the Listed arrow over its label

**File:** `UI/Table.lua:1182-1184`, `UI/Table.lua:1197-1198`
**Issue:** WR-05 was fixed for the template path only.
- Without `b.Text`, the label fills the button (`SetAllPoints`), and Listed's text is right-justified to the edge.
- The arrow is anchored at `b` RIGHT -2, so on the Listed column it sits on top of the label's last letters.

This happens only with the atlas but without the template, an unlikely combination on Forever.
**Fix:** on the fallback path, inset the label (`SetPoint("LEFT", 4, 0)` and `SetPoint("RIGHT", -14, 0)`) whenever an arrow is created. Or anchor the arrow to the button's LEFT for RIGHT-justified columns.

### IN-08: In game with preview data on, Blizzard's searching/failed flags still blank the table

**File:** `UI/InPlace.lua:70-75`, `UI/Table.lua:915`, `UI/Table.lua:924`
**Issue:** `source.listings()` and `source.preview()` switch to sample data when `ns.UsingPreview()` is true. `searching()` and `failed()` do not switch, and keep reading `LFGBrowseFrame`. After a failed real search, `searchFailed` stays true until the next `LFGBrowse_DoSearch`, so the sample listings are replaced by "Search failed." and the selection is dropped.
**Fix:** return `false` from `searching()` and `failed()` while `ns.UsingPreview()` is true.

### IN-09: During chat messaging lockdown the table reads no listings at all

**File:** `Listings.lua:171-173`
**Issue:** While `InChatMessagingLockdown()` is true:
- `L.Read()` wipes `items` and returns an empty list.
- The table then shows "No results found." over Blizzard's hidden list, which still holds real results.
- Your own listing row disappears too.

The values that are actually secret are already skipped per field (the `Secret()` checks), so the blanket return hides more than it needs to.
**Fix:** drop the blanket early return and rely on the per-value `Secret()` guards. Or keep it, and give `Refresh` a distinct state text ("Listings unavailable right now") instead of reporting no results.

---

_Reviewed: 2026-11-11T17:32:19Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
