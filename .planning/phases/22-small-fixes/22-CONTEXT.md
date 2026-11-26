# Phase 22: Small Fixes - Context

**Gathered:** 2026-11-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Three fixes to what shipped in v0.3.0, nothing new beyond them:

1. The elite quest eye's click path never raises a Lua error (QST-05)
2. A row marked "invited" shows how the invite ended: accepted, declined or expired (INV-01, INV-02)
3. The first search after a `/reload` or login shows the picked activity, not the category's
   general view (SRCH-01)

</domain>

<decisions>
## Implementation Decisions

Taken at milestone kickoff and the autonomous run's up-front batch (2026-11-26), by the author.

### Elite quest eye guards (QST-05)
- No error text was recorded: guard every step of the click rather than one known failure:
  `Q.Cover` / `Q.Recheck` / `Q.Uncover`, the cover's OnEnter / OnLeave / OnMouseDown / OnMouseUp,
  `Arm` (PreClick), `After` (PostClick), the two delegates' PreClick (`CategoryButton()`,
  `ActivityCheck()`), `FocusDescription`, `Q.ShowHint` and the outline, and the eye's own
  click (`Q.Click`)
- Guards: nil / type checks on every frame and method read from Blizzard's finder
  (`LFGListingFrame:GetCategorySelection`, `IsActivitySelected`, `ActivityView`, the
  ScrollBox, the tab and micro buttons), and `pcall` around steps that call into Blizzard code;
  never `pcall` around a secure attribute set in a way that would leave the cover armed with a
  stale macro: on failure, `Arm` clears `macrotext` so the click does nothing
- A failed step prints `[TGF] Quest eye: <what failed>` once (not on every hover; throttled per
  distinct message), keeps the error in `Q.lastError` for `/tgf quest`, and leaves the eye
  usable on the next click (the cover hides cleanly, highlight unlocked)
- The secure-click route, the macro's targets and the taint rules in CLAUDE.md stay exactly as
  they are; no new writes on Blizzard frames

### Invite outcome (INV-01, INV-02)
- After the addon's Group Invite button or Auto-invite (the only places that set
  `ns.state.invited`), the row's Listed cell reads, by outcome:
  - "accepted" (green) when the player joins your group (`GROUP_ROSTER_UPDATE` with that name
    in the group, and/or the game's join system message `ERR_JOINED_GROUP_S` /
    `ERR_RAID_MEMBER_ADDED_S`)
  - "declined" (red) on `ERR_DECLINE_GROUP_S`; also on immediate refusals (already in a group
    `ERR_ALREADY_IN_GROUP_S`, ignoring you, player not found / offline): author's choice, they
    show "declined"
  - "expired" (grey) when the game says the invite expired (if Forever sends such a message);
    otherwise our own timer marks it expired 2 minutes after the invite with no answer
  - "invited" (green) while waiting, as now
- Messages are matched by plain character name (Forever's one mega-realm; strip any realm
  suffix before comparing), built from the game's global format strings (never hard-coded
  English) turned into patterns; `CHAT_MSG_SYSTEM` text guarded with `issecretvalue`
- Kept in `ns.state` by listing ID next to `invited` (the outcome follows its listing through
  Dynamic refresh, re-sort and `Listings.Key` remapping exactly as `invited` / `messaged` do);
  greyed rows show the word in stock grey; whisper-only rows keep "sent"
- A new invite to the same player resets the outcome to "invited"
- Preview: the preview's invite resolves after a few seconds to an outcome (random or cycled)
  so all three can be seen in `/tgf preview`

### First search after a reload (SRCH-01)
- Root cause (read from `Blizzard_LFGVanilla_Browse.lua`): picking a category runs
  `LFGBrowse_DoSearch` for the whole category; the first search after a reload is slow, and
  picking the activity while it is out calls `LFGBrowse_DoSearch` again, which does nothing
  while `LFGBrowseFrame.searching` is true. The answer is the category's general view
- The addon must not search again itself (`C_LFGList.Search` is blocked from timers / events;
  CLAUDE.md taint rules)
- Fix (author's choice, "Show only picked"): when an answer arrives for a search wider than the
  activities now picked in the dropdown (same category; searched with no activities or a
  different set), the table narrows that answer to the listings with at least one picked
  activity, so it shows what an activity search would give. `shownFilter` then becomes the
  current filter, so the next refresh is a normal Dynamic refresh of it
- Narrowing applies only in that mismatch case; a normal answer is read unchanged. Selection,
  sections, sorting, greying and Needs my role work on the narrowed list as on any list
- Must also work with Dynamic refresh off and in the preview path (no regressions)

### Claude's Discretion
- Exact helper names, where the narrowing lives (`Listings.Read` filter argument vs the
  `source.listings` function), the expiry timer mechanism (one ticker vs `C_Timer.After` per
  invite), throttle details for the eye's chat line
- Whether join detection uses the roster, the system message, or both (both is safest)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `QuestButton.lua`: `Q.lastError`, `Q.failed`, `Q.Probe` (`/tgf quest`), `Secret()`,
  `PlainNumber()`; the click route lives at `QuestButton.lua:581-756` (`Arm`,
  `FocusDescription`, `After`, `BuildCover`, `Q.Cover`, `Q.Recheck`, `Q.Uncover`)
- `ns.state.invited` / `ns.state.messaged` (set in `UI/Table.lua:750` `Instance:Invite` and
  `Messages.lua:308/332` Auto-invite), read at `UI/Table.lua:1413` for the Listed cell
- `UI/InPlace.lua`: `FilterKey()`, `issued`, `shownFilter`, `searchOut`, `OnSearch` (hook on
  `LFGBrowse_DoSearch`), the results event handler, `Read()` / `ReadSoon()`
- `ns.Listings.Read(snapshot)`, `ns.Listings.Key`

### Established Patterns
- Every Blizzard read guarded (`issecretvalue`, type checks); pcall-guarded installers;
  `ns.Print` for chat lines with the `[TGF]` tag
- Preview behaviour mirrors the game path through `ns.UsingPreview()` branches

### Integration Points
- Invite outcome: a small event frame (CHAT_MSG_SYSTEM, GROUP_ROSTER_UPDATE) in `Messages.lua`
  or `UI/Table.lua`; the Listed cell text in `UI/Table.lua`; redraw with `ns.Table.RefreshAll()`
- Search: the `LFG_LIST_SEARCH_RESULTS_RECEIVED` branch in `UI/InPlace.lua` (where
  `shownFilter = issued`) and `ns.Listings.Read`

</code_context>

<specifics>
## Specific Ideas

- Colours: accepted green (as "invited" now, `|cff33ff33`), declined red (as "delisted",
  `|cffff3333`), expired grey; stock grey on greyed rows
- Chat line: `[TGF] Quest eye: <what failed>`

</specifics>

<deferred>
## Deferred Ideas

- Outcomes for invites sent outside the addon's buttons (chat, unit menu)
- Distinct states for each kind of refusal

</deferred>
