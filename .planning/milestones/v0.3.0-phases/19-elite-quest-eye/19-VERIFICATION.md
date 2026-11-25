---
phase: 19-elite-quest-eye
verified: 2026-11-24T00:00:00Z
status: passed # in-game checks passed by the author, 2026-11-25, with round 2's changes (21-HUMAN-UAT.md item 5)
score: 4/4 requirements verified in code; in-game behaviour pending
overrides_applied: 0
human_verification:
  - test: "Track an elite quest (and an elite campaign quest) in the objective tracker"
    expected: "An eye on a square button appears at the block's top right, retail look; non-elite quests show none; long titles keep their line count or run under the eye"
    why_human: "Needs the live tracker layout and Forever's IsEliteQuest answers"
  - test: "Hover the eye"
    expected: "Tooltip: gold 'Find a group for this quest' with the note line"
    why_human: "Visual"
  - test: "Click the eye out of combat"
    expected: "Finder opens on the Listing tab; hint box (Elite tag + quest name, Category, Zone, Description) shows at the top of the tab with a close button; the Quests & Zones button is outlined; finder widens. Post and Search still work afterwards (no ADDON_ACTION_BLOCKED / taint)"
    why_human: "Taint and layout can only be checked in game"
  - test: "Hint clearing"
    expected: "Hint and outline clear when the finder closes, another tab is selected, a listing is made, the close button is used, or combat starts"
    why_human: "Runtime events"
  - test: "Click the eye in combat"
    expected: "Chat line 'can't open the group finder in combat.' and nothing opens"
    why_human: "Needs combat"
  - test: "A quest the game gives its own find-group eye (CanCreateQuestGroup true)"
    expected: "No second eye of ours"
    why_human: "Depends on live game data"
  - test: "Toggle 'Elite quest button' in Settings and /tgf set eliteQuestButton off|on; run /tgf quest"
    expected: "Eyes hide / show at once; probe lists tracked quests, elite tags, eye shown, category 116 activities"
    why_human: "Live tracker"
---

# Phase 19: Elite Quest Eye Verification Report

**Phase Goal:** From a tracked elite quest, one click takes the player to Forever's Listing tab with what they need to post a group for it
**Status:** human_needed (no code gaps found; only in-game checks open)
**Re-verification:** No

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | QST-01: elite tracked quests show a retail-look eye with tooltip; others none | VERIFIED | `QuestButton.lua` `Eligible` uses `C_QuestLog.IsEliteQuest` with tag-ID fallback (no title text); `NewEye` 30x30 `UI-SquareButton-*`, `socialqueuing-icon-eye` 13x13 with stock-icon fallback, press nudge; tooltip via `W.ShowTip` "Find a group for this quest" + note; Quest and Campaign modules hooked via `hooksecurefunc(module,"EndLayout",Pass)`; `ContinueOnAddOnLoaded` fallback |
| 2 | QST-02: out-of-combat click opens Listing tab; combat prints a line and does nothing | VERIFIED | `Q.Click` reads `eye:GetParent().id`, combat check prints "can't open the group finder in combat.", calls `ns.InPlace.ShowFinder(LISTING_TAB)`; `IP.ShowFinder` calls `LFGVanilla_ShowFrame(tab)` (UI/InPlace.lua:454); `IP.OpenMessages` refactored through it with Settings wait and `ShowMessages()` kept |
| 3 | QST-03: hint shows quest name, category, zone; clears on finder hide / tab change / listing / close / combat; nothing of Blizzard's selected or written | VERIFIED (code) | `BuildHint`: frame of ours parented to `LFGListingFrame` (dialog border, `UIPanelCloseButton`); hides with the Listing frame (covers finder close and tab change), `LFG_LIST_ACTIVE_ENTRY_UPDATE` with active entry, `PLAYER_REGEN_DISABLED`, close button; own outline frame on the category 116 button found read-only, atlas with plain fallback; zone from log/task/map, omitted if unknown; chat-line fallback in preview. No `SetSearchToQuestID`/`SetSearchToActivity`/`CreateListing`/`UpdateListing`/`Search` anywhere in `QuestButton.lua` |
| 4 | QST-04: no duplicate game eye; no taint | VERIFIED (code) | `Eligible` excludes `C_LFGList.CanCreateQuestGroup == true` (direct C call, not `QuestUtil`); `HasGameEye(block)` read-only guard; eyes in a weak-keyed table, never fields on blocks; only Blizzard write is HeaderText RIGHT anchor, reverted if the line count changes and by the block's own layout; no anchoring to the item button in combat (deferred to `PLAYER_REGEN_ENABLED`). Taint-freedom itself is a human check |

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `QuestButton.lua` (825 lines) | VERIFIED | `ns.QuestButton`; eye, hint, outline, `Q.Probe` |
| `UI/InPlace.lua` | VERIFIED | `IP.ShowFinder`, `IP.LISTING_TAB = 1`, `IP.WidenListing` |
| `TerribleGroupFinder.toc` | VERIFIED | `QuestButton.lua` after `ItemLevelUI.lua` |
| `Core.lua` | VERIFIED | `ns.QuestButton.Init()` (line 330); `/tgf quest` -> `Probe` (line 362); usage line lists `quest` |
| `Settings.lua` | VERIFIED | `eliteQuestButton` registered (line 124); read live by `UpdateBlock`, `OnChange` -> `RefreshAll` |
| `CLAUDE.md` | VERIFIED | QuestButton.lua entry present (line 29); `grep -i "phase [0-9]"` finds none (only generic "Release Review phase" / "multi-phase" wording, not phase numbers) |

## Locked decisions

Tracker only (no quest log eye): honored. Retail-look eye: honored. Tooltip title exact: honored. Listing tab plus hint box with close button: honored. Outline on Quests & Zones (116): honored. Combat chat line: honored. Nothing of Blizzard's finder selected, filled or written, no `SetSearchToQuestID`: honored. Elite campaign quests included: honored.

## Requirements Coverage

| Requirement | Source Plan | Status |
|-------------|-------------|--------|
| QST-01 | 19-01 | SATISFIED (code) |
| QST-02 | 19-01 | SATISFIED (code) |
| QST-03 | 19-02 | SATISFIED (code) |
| QST-04 | 19-01, 19-02 | SATISFIED (code; taint check in game) |

No orphaned requirements: REQUIREMENTS.md maps QST-01..04 to Phase 19 and all four are claimed by the plans. Note REQUIREMENTS.md still shows them unchecked / "Pending"; update at phase close.

## Anti-Patterns

None blocking. No TBD/FIXME/XXX markers; `stylua --check .` passes; git tree clean.

## Gaps Summary

No code gaps. Remaining items are in-game checks (listed in frontmatter).

_Verifier: Claude (gsd-verifier)_
