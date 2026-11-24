---
phase: 19-elite-quest-eye
plan: 02
subsystem: ui
tags: [group-finder, quest, hint, outline, probe]
requires:
  - phase: 19-01
    provides: IP.ShowFinder, QuestButton.lua eye
provides:
  - Listing-tab hint box and Quests & Zones outline (QST-03)
  - IP.WidenListing(extra)
  - /tgf quest probe
affects: []
key-files:
  modified: [QuestButton.lua, UI/InPlace.lua, Core.lua, CLAUDE.md]
requirements-completed: [QST-03, QST-04]
completed: 2026-11-24
---

# Phase 19 Plan 02: Quest Hint and Probe Summary

After the eye's click opens the Listing tab, a dialog-style box of ours shows the quest name (gold, Elite tag), Category, Zone and the description to type, with a pulsing outline on the Quests & Zones button; nothing of Blizzard's finder is selected, filled, clicked or written.

## Commits
- b6aaebb feat(19-02): quest hint box and category outline on the Listing tab
- 9c0d873 feat(19-02): /tgf quest probe and CLAUDE.md entries for the quest eye

## What was built
- `IP.WidenListing(extra)` and the Browse `OnHide` hook keeping the Listing strip.
- Hint box (one line per field, width-bound, height clamped to 100), outline (atlas, or four gold edges), clear triggers (finder hide, tab change via the Listing OnHide hook, listing made, close button, combat start), chat line instead of the box for an active listing, a missing finder width API, or the stand-in.
- Zone sources: quest log header, task quest zone, quest UI map; `Q.ZoneSources`, `Q.HintLine`, `Q.Probe`.
- `/tgf quest` and `quest` in USAGE (stylua wrapped the USAGE line).
- CLAUDE.md: QuestButton.lua line, taint exceptions, InPlace line, Core command list, and the Settings line now says `QuestButton.lua` reads `eliteQuestButton` (no phase numbers left).

## Deviations from Plan
- None in behaviour. The hint's category / zone lines are also single-line (the plan only required it for title and description), to keep the box under the height clamp.

## In-game checks (not testable here)
- Click the eye: Listing tab opens, finder widens, hint at the top right of the roles band covers no control, outline pulses on Quests & Zones.
- Hint clears on closing the finder, switching to Browse / Who / Messages, posting a listing, the close button, entering combat; width returns each time (also after Browse hides while Listing shows).
- With an active listing: one chat line, no box.
- Long quest name is cut, not wrapped; unknown zone omits the Zone line.
- Post and Search by hand afterwards with `/console taintLog 2`: no ADDON_ACTION_BLOCKED.
- `/tgf quest` output; stand-in (no finder API) click prints one chat line.
- Screenshot reminder: tracker eye and Listing hint are new UI (README prints, the author retakes).

## Self-Check: PASSED
Commits b6aaebb and 9c0d873 exist; stylua --check passes; forbidden-call and field-write greps print 0; CHANGELOG.md / README.md untouched; every local in QuestButton.lua is defined above its first caller.
