---
phase: 03-rows-tooltip-and-own-listing
verified: 2026-11-11T00:00:00Z
status: human_needed
score: 5/5 must-haves verified in code (visual and live checks pending)
overrides_applied: 0
gaps: []
human_verification:
  - test: "Delist from our own row (solo and leader); check a non-leader group member"
    expected: "Stock delist button appears only for solo or leader; click removes the own row; no ADDON_ACTION_BLOCKED"
    why_human: "Restricted call and real listing state"
  - test: "Hide button icon legibility"
    expected: "transmog-icon-hidden / socialqueuing-icon-eye at 16 px in 24x22 button, else the x / + fallback; never a red X"
    why_human: "Atlas existence and look"
  - test: "Micro role icons on solo rows"
    expected: "18 px, square, legible; groups keep large 14 px icons"
    why_human: "Visual"
  - test: "Discord icon and voice wording"
    expected: "Icon level with the name, name truncation fine; tooltip 'Voice chat: <mode>' matches stock"
    why_human: "Atlas UI-ChatIcon-Discord existence and layout"
  - test: "Tooltip order and wording against the stock tooltip on the same listing"
    expected: "Same order/wording; comment light grey; then playstyle, spec/area, friends in group, listed age, hidden note"
    why_human: "Side-by-side visual compare"
  - test: "Playstyle colour (see note)"
    expected: "ROADMAP SC3 says playstyle in light grey; code and UI-SPEC D-17 render it green as the stock row's PlaystyleLabel. Author confirms green is acceptable or asks for light grey"
    why_human: "Roadmap wording vs documented decision; author choice"
  - test: "Tooltip refresh while hovered during a results update and while scrolling"
    expected: "Tooltip follows the listing under the mouse; hides when none"
    why_human: "Live event timing"
  - test: "Needs my role on a quest / custom-activity group"
    expected: "Listings reporting no slot for your role are greyed and moved to the end of their section; zero-count groups fall back to the estimate"
    why_human: "Real server remaining-slot data"
  - test: "Atlas existence: UI-ChatIcon-Discord, groupfinder-icon-role-micro-*, newplayerchat-chaticon-newcomer, groupfinder-icon-leader"
    expected: "All render, or the coded fallbacks show"
    why_human: "Client asset check"
  - test: "/console taintLog 1 while hovering rows and clicking delist / hide"
    expected: "No taint messages"
    why_human: "Taint log is in-game only"
  - test: "Q1 620 width with Activity readable; then /reload"
    expected: "Activity column readable at the widened frame"
    why_human: "Visual"
---

# Phase 3: Rows, Tooltip and Own Listing Verification Report

**Phase Goal:** Each row and its tooltip read like Forever's own: solo players with role icons, your own listing with its delist button, and a tooltip in the stock order.
**Verified:** 2026-11-11
**Status:** human_needed
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Solo players show stock micro role icons; voice icon and wording match stock | VERIFIED (look pending) | `UI/Widgets.lua:412-425` `SetRole(role, micro)` uses `groupfinder-icon-role-micro-*` with fallback; `UI/Table.lua:713` solo rows use micro 18 px; Discord icon via `UI-ChatIcon-Discord` with text-tag fallback (`Table.lua:1032-1034`); `VOICE_CHAT_MODE_FORMAT` and `VOICE_CHAT_MODE_*` labels (`Table.lua:369-374, 551`) |
| 2 | Own row shows "Your listing" in green and, as solo or leader, the stock delist button | VERIFIED | `Table.lua:1071` `LFG_SELF_LISTING`, colour `W.LIGHTGREEN` (`:1099`); `row.delist` shown only when `l.mine and CanUnlist(self)` (`:1130`); `CanUnlist` re-checked on click and calls only `C_LFGList.RemoveListing` (`:653-689`) |
| 3 | Tooltip in stock order and wording, comment in light grey, then friends in group and hidden note; refreshes on results update | VERIFIED (playstyle colour note) | `StockTooltip` (`:497-580`): delisted/new-player, leader+members with GS, comment `W.LIGHTGRAY`, members counts, voice, activities, bosses; `ExtrasTooltip` (`:565-590`): playstyle, spec/area, friends in group, listed age, hidden note. `HoveredRow`/`RefreshTooltip` (`:1192-1230`) called at every exit of `Instance:Refresh` (`:1261, 1272, 1299`), event-driven only. Note: playstyle is green (stock row PlaystyleLabel, UI-SPEC D-17), ROADMAP wording says light grey; flagged for author |
| 4 | Hide button is a small stock-style button with an icon | VERIFIED (look pending) | `W.IconButton` (`Widgets.lua:318`), `row.hide` 22 px high (`Table.lua:852`), eye atlases when present, x / + fallback (`:1121-1128`) |
| 5 | Needs my role uses server remaining-slot counts; no-slot listings greyed and moved to section end | VERIFIED (live data pending) | `Listings.lua:194` reads `l.remaining`; `Table.lua:163-172` uses it, with the estimate when counts are all zero for a non-full group; greyed/end-of-section via the shared greyed rule (`:213`) |

**Score:** 5/5 truths verified in code

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| UIP-07 | 03-02, 03-03 | SATISFIED (visual pending) | Truth 1 |
| UIP-08 | 03-02 | SATISFIED | Truth 2 |
| UIP-09 | 03-03 | SATISFIED (colour note) | Truth 3 |
| UIP-13 | 03-02, 03-03 | SATISFIED (colour note) | Comment light grey; playstyle in tooltip extras |
| UIP-14 | 03-02 | SATISFIED | Truth 4 |
| UIP-15 | 03-01 | SATISFIED | Truth 5 |
| UIP-16 | 03-04 | SATISFIED | Truth 3 refresh |

All seven IDs appear in PLAN frontmatter and are marked complete in REQUIREMENTS.md. No orphaned Phase 3 requirements.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Smoke harness default, `--gs`, `--fallback`, `--attach` | `node run.js <repo> [flag]` | each `SUMMARY: 0 failed` | PASS |
| Formatting | `stylua --check .` | clean | PASS |

### Taint Rules

Only `Hide()`, `HookScript`, our own frames and `GameTooltip` calls are used. `Search`, `CreateListing` and `UpdateListing` are not called; the only restricted call is `RemoveListing` from the user's click on our delist button. No fields are written on Blizzard's finder in the code read. Live taint log pending (human item).

### Anti-Patterns Found

None. No TBD/FIXME/XXX in Lua files. Review fixes (03-REVIEW-FIX.md) are applied in HEAD.

### Gaps Summary

No code gaps. Status is human_needed because looks, atlas existence, taint log and real server data can only be checked in game, and the playstyle colour needs the author's decision (green as built vs light grey in the ROADMAP wording). If green is accepted, add an override for SC3 wording.

---

_Verified: 2026-11-11_
_Verifier: Claude (gsd-verifier)_
