# Phase 9: Dynamic Refresh - Context

**Gathered:** 2026-11-14
**Status:** Ready for planning
**Mode:** Smart discuss, recommended answers auto-accepted (author: never pause autonomous runs; decisions listed for review at the end)

<domain>
## Phase Boundary

Finish the quiet refresh prototype as "Dynamic refresh": the game's own search of the same category and activities (the refresh button) keeps the list on screen and updates it in place, with calmer swipes, rows below a removed one sliding up, and the same animations playable in the preview. Gated by `ns.Settings` keys `dynamicRefresh` and `swipeAnimations` (independent). The settings page itself is Phase 10.

</domain>

<decisions>
## Implementation Decisions

### Behaviour (author, from the prototype)
- Name: "Dynamic refresh" everywhere user-facing (code comments, CLAUDE.md, later the settings page)
- Same category + activities searched again: list stays (no spinner, no blank), answer replaces it in place: new listings sorted in, listings that went (delisted / no longer returned) removed, the selection and whispered / invited marks follow their listing by key, a failed refresh keeps the list; any other search is a new list (stock behaviour)
- No refresh on a timer (the game blocks `C_LFGList.Search` from a timer: `ADDON_ACTION_BLOCKED`); only the game's own searches. There is no addon icon over the refresh button any more (the prototype's Auto-refresh icon was removed); nothing to rename
- `dynamicRefresh` off: stock behaviour (spinner, blank list, new list); `swipeAnimations` off (with Dynamic refresh on): the list updates in place without animation

### Animation feel
- Author: "slow them down a bit" from the prototype's 0.25 s: swipe out ≈ 0.4 s, swipe in ≈ 0.4 s, slide-up ≈ 0.3 s, as named constants in one place (`UI/Motion.lua`), smoothing "OUT"
- Order: leaving rows swipe out (left, fade) → list updates → rows below slide up from their old positions while new rows swipe in (right, fade) at the same time
- Total wait before the list updates stays short (the swipe-out only); a new search during a swipe cancels it and shows the new state at once
- Clicks on rows during the swipe-out are ignored (the rows still hold the old results)
- Rows filtered out (search box, Needs my role) or in a collapsed section just change, no animation

### Preview (author: "have some of it show on preview mode so I can test and give feedback")
- The preview's refresh button runs a simulated Dynamic refresh: 1–3 listings leave, 1–3 new ones arrive from a reserve, sometimes one turns delisted, through the same `Motion` path as the game; repeated presses keep churning; `/tgf reset` restores the sample data
- The preview honours both settings the same way as the game

### From research (locked technical choices)
- Extract `UI/Motion.lua` (`ns.Motion`) from `UI/Table.lua` / `UI/InPlace.lua`: swipe out / in, slide-up (record each row's `GetTop()` by listing key before the update, animate from the old offset after it), `Motion.Show(previousKeys, selectedKey)` shared by the live path and the preview
- Pooled rows: reset (stop group, alpha 1, offsets) in the ScrollBox element resetter as well as in `FillRow`; never move anchors of pooled rows; no `UIFrameFade` / `OnUpdate` tweens (AnimationGroup Translation + Alpha only); W.List fallback supported

### Claude's Discretion
- Exact constants within the ranges above; how many reserve listings the preview holds
- Harness stubs (GetTop recorder, animation recorder)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `UI/InPlace.lua`: `OnSearch` (FilterKey, refresh state), `Read`, `ShowRefresh`, `ReadSoon`, swiping / readAfterSwipe flags
- `UI/Table.lua`: `T.SWIPE`, `Swipe`, `SwipeRows`, `T.SwipeOut`, `T.SwipeIn`, `FillRow` swipe reset, `T.SelectedKey`, `T.SelectKey`
- `Listings.lua`: `L.Key`, `L.Snapshot`, `L.Read(previous)` (carry marks, drop delisted)
- `Preview.lua` sample listings (`Add`, `Group`, `Solo`, sample shards), `UI/MainFrame.lua` preview refresh button, `/tgf reset` (`ResetState`)
- `Settings.lua`: `dynamicRefresh`, `swipeAnimations` registered (default on)

### Integration Points
- `UI/InPlace.lua` OnSearch / Read / ShowRefresh → `ns.Motion`; preview refresh in `UI/MainFrame.lua`; TOC (add `UI/Motion.lua` before `UI/Table.lua` or wherever load order needs)

</code_context>

<specifics>
## Specific Ideas

- Author: "can we have a basic swiping animation or something for the removed groups and added ones? ... makes everything look clean"; "animation looks good ... we will need to slow them down a bit"

</specifics>

<deferred>
## Deferred Ideas

- Respecting a reduced-motion accessibility setting (if Forever exposes one) — not in v0.2

</deferred>
