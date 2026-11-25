---
phase: 19-elite-quest-eye
plan: 01
subsystem: ui
tags: [objective-tracker, quest, group-finder, hooksecurefunc]
requires:
  - phase: 18
    provides: eliteQuestButton setting
provides:
  - ns.QuestButton (eye on tracked elite quests, tooltip, click)
  - IP.ShowFinder(tab), IP.LISTING_TAB
affects: [19-02]
key-files:
  created: [QuestButton.lua]
  modified: [UI/InPlace.lua, TerribleGroupFinder.toc, Core.lua]
requirements-completed: [QST-01, QST-02, QST-04]
completed: 2026-11-24
---

# Phase 19 Plan 01: Elite Quest Eye Summary

Retail-style eye button of ours on tracked elite quests (Quest and Campaign tracker modules) via a post-hook on EndLayout, opening Forever's Listing tab through the new IP.ShowFinder.

## Commits
- 03ab6f7 refactor(19-01): extract IP.ShowFinder(tab) from IP.OpenMessages
- 44a2ce5 feat(19-01): elite quest eye on tracked elite quests

## What was built
- `IP.ShowFinder(tab)`: combat refusal, "isn't ready" message, `LFGVanilla_ShowFrame(tab)` (ToggleFrame fallback only while hidden). `IP.OpenMessages` calls it only while the finder is hidden; otherwise unchanged.
- `QuestButton.lua`: weak-keyed eyes, eligibility cache (IsEliteQuest, tag fallback, game-eye guard via `C_LFGList.CanCreateQuestGroup`), premade check, header room only when line count is kept, pcall-guarded pass and installer (`Q.failed`, `Q.lastError`), setting toggle via `OnChange`, re-run after combat.
- TOC line after ItemLevelUI.lua (before GearSlots.lua); `ns.QuestButton.Init()` after `ns.InPlace.Init()`.

## Deviations from Plan
- Did not add an unused `local LISTING_TAB`; only `IP.LISTING_TAB = 1` is exported (stylua/unused local).
- The OpenMessages `LFGVanilla_` count was 4 before (not 3); now 0.
- The TOC line was written LF by the Edit tool and normalised back to the file's CRLF.

## In-game checks (not testable here)
- Eye shows on a tracked elite quest in Quest and Campaign modules; none on non-elite quests; none beside Blizzard's own eye.
- Tooltip title and note text; press nudge of the icon; atlas fallback if missing.
- Toggling eliteQuestButton (Settings / `/tgf set`) shows/hides every eye at once.
- Click opens Listing tab; in combat prints the refusal and opens nothing; Messages button of Settings still works.
- Long titles keep their line count; eye sits over the title end otherwise.
- Taint log clean after posting a listing and searching by hand, and after quest item use in combat.

## Self-Check: PASSED
QuestButton.lua exists; commits 03ab6f7 and 44a2ce5 exist; every local in QuestButton.lua is defined above its first caller; stylua --check passes.
