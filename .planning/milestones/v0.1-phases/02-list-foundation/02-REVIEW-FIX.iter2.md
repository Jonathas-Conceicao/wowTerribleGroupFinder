---
phase: 02-list-foundation
fixed_at: 2026-11-11T17:28:37Z
review_path: .planning/phases/02-list-foundation/02-REVIEW.md
iteration: 1
findings_in_scope: 12
fixed: 12
skipped: 0
status: all_fixed
---

# Phase 2: Code Review Fix Report

**Fixed at:** 2026-11-11T17:28:37Z
**Source review:** .planning/phases/02-list-foundation/02-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 12 (Warnings; Info findings IN-01 to IN-05 out of scope)
- Fixed: 12
- Skipped: 0

**Verification:**
- After every fix: `stylua`, then the smoke harness in all four modes (default, `--gs`, `--fallback`, `--attach`). Each run ended with `SUMMARY: 0 failed`.
- The harness checks were not changed.
- `stylua --check .` passes.

## Fixed Issues

### WR-01: A dropped selection still draws as selected

**Files modified:** `UI/Table.lua`
**Commit:** f701163
**Applied fix:**
- Split the drop logic out of `RefreshButtons` into `Instance:ValidateSelection()`.
- `Refresh` now calls it after `Collect()` and before `SetItems`. A gone or delisted selection is cleared before any row is filled.
- `RefreshButtons` still calls it, so the row-click path is unchanged.

**Status:** fixed: requires human verification (logic change)

### WR-02: A failed search keeps the old rows under the "Search failed." text

**Files modified:** `UI/Table.lua`
**Commit:** b50c8b8
**Applied fix:** when `source.failed()` is true, `Refresh` now:
- clears the list (`list:Clear()`) and the selection;
- shows `LFG_LIST_SEARCH_FAILED`;
- empties the status line;
- refreshes the buttons, then returns.

This matches stock `UpdateResults`. The failed case was taken out of the later state chain.

**Status:** fixed: requires human verification (logic change)

### WR-03: Send Message / Group Invite can act on a listing you can't see

**Files modified:** `UI/Table.lua`
**Commit:** 405c965
**Applied fix:** this uses the review's alternative: keep the selection, but disable the buttons while its row is hidden.
- `Collect()` now fills `inst.shownIDs` with the IDs of the rows it actually emits (matching the search, not folded).
- A new `ShownSelection(inst)` returns the selected listing only while its row is shown.
- `RefreshButtons` enables Send Message / Group Invite from `ShownSelection`, and the two buttons act on it.
- A selection that is filtered out or folded away is kept. Its row shows it as selected again when it comes back, but nothing acts on it while it is hidden.
- I tried dropping the selection on fold first. That broke the existing harness check "header clicks keep the selection" (D-09), so I rolled it back and used this approach instead.

**Status:** fixed: requires human verification (logic change)

### WR-04: The stand-in's BarTop / BarMiddle lines have zero height wherever the atlas exists

**Files modified:** `UI/MainFrame.lua`
**Commit:** b02114c
**Applied fix:**
- A local `ScrollLine()` helper uses `SetAtlas("groupfinder-ScrollLine", true)` (atlas size, like stock's `useAtlasSize`) when the atlas exists.
- Where it doesn't, the helper falls back to a 1 px colour line.
- BarTop and BarMiddle both use the helper.

### WR-05: The "Listed" header label is pushed 4 px outside its button

**Files modified:** `UI/Table.lua`
**Commit:** ddde5d6
**Applied fix:**
- The header label's x offset now follows its justification: LEFT +4, CENTER 0, RIGHT -4.
- On right-justified columns, the sort arrow is anchored to the text's LEFT (-3), so it stays inside the Listed cell.

### WR-06: The fallback W.List rows don't line up with the header strip

**Files modified:** `UI/Table.lua`
**Commit:** 35cf9d9
**Applied fix:**
- `PlaceStrip` now takes an optional `inset`.
- The fallback `W.List` path calls `placeStrip(false, -14)`: the list's -6 plus W.List's -8 frame inset. The header's right-side columns now match the rows'.
- The ScrollBox callback is unchanged.

### WR-07: "Your GS" is anchored over the Needs my role label

**Files modified:** `UI/Table.lua`
**Commit:** 66f03f4
**Applied fix:**
- The status keeps its RIGHT anchor at Group Invite.
- With GS on, `myGS` is anchored LEFT to the Needs my role label (+12), and the status LEFT to `myGS` RIGHT (+8).
- With GS off, the anchors are unchanged.

### WR-08: Greyed rows keep coloured fragments

**Files modified:** `UI/Table.lua`
**Commit:** 69f3bbb
**Applied fix:** on greyed rows, the name line and the activity text now go through `Plain()`. This covers the "+N" suffix, the fallback name tags and the "(you)" colour codes.

Inline `|A` atlas icons are kept, and are not desaturated. Markup can't desaturate them, and removing them would lose information.

### WR-09: The search box's text insets cover SearchBoxTemplate's magnifier and clear button

**Files modified:** `UI/Widgets.lua`
**Commit:** 6bac602
**Applied fix:** `W.EditBox` only calls `SetTextInsets(2, 2, 0, 0)` when the box has no `searchIcon`. That covers `InputBoxTemplate` and the fallback. A real `SearchBoxTemplate` keeps its own 16/20 insets. I confirmed the `searchIcon` parentKey in `InputBoxTemplates.xml` on `forever`.

### WR-10: The `pcall` around the comment search does not cover `lower()`

**Files modified:** `UI/Table.lua`, `Listings.lua`
**Commit:** 135272c
**Applied fix:**
- `Matches` now runs `find(lower(c), ...)` inside one pcall'd closure.
- The comment stays searchable, as D-14's "Name, activity or note" placeholder promises.
- The comment in `Listings.lua` that said the comment "is not searched" now says the search reads it only inside a pcall.

### WR-11: Unlist calls `C_LFGList.RemoveListing()` for any listing that contains you

**Files modified:** `UI/Table.lua`
**Commit:** 1096860
**Applied fix:** this is the minimal fix the orchestrator allowed.
- A new `CanUnlist(inst)` returns true in the preview; in game it requires `not IsInGroup() or UnitIsGroupLeader("player")`, Forever's rule for its delist button.
- The own row's Unlist button is enabled only when `CanUnlist` is true.
- `Instance:Message` also returns early for your own listing when you can't unlist.
- The direct `C_LFGList.RemoveListing()` call stays.
- Deferred to Phase 3 (UIP-08), which brings the stock delist button: routing the unlist through Blizzard's own UI and setting `PENDING_LISTING_UPDATE`.
- Still to check in game: that `RemoveListing` is not blocked when called from addon code, and that the Listing tab refreshes afterwards.

**Status:** fixed: requires human verification (logic change)

### WR-12: Group Invite uses `fullName`, against the plain-name rule in CLAUDE.md

**Files modified:** `UI/Table.lua`
**Commit:** 1e96b01
**Applied fix:** `C_PartyInfo.InviteUnit(l.leader.name)`, with a comment citing the mega-realm rule.

**Note:** `Messages.lua:100` (`M.Send`) still whispers `l.leader.fullName or l.leader.name`, which breaks the same CLAUDE.md rule for whispers. It was outside this finding and the reviewed file set (Messages is Phase 4), so the fixer did not change it. Follow-up done by the orchestrator in `b60696e` (`fix(02): whisper by plain character name`).

---

_Fixed: 2026-11-11T17:28:37Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
