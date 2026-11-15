---
phase: 10-settings-window
verified: 2026-11-14T00:00:00Z
status: human_needed
score: 5/5 must-haves verified (code level)
human_verification:
  - test: "In Forever, open Settings > AddOns > TerribleGroupFinder and run /tgf settings"
    expected: "Page lists Item level (4), Group finder (3, Swipe indented under Dynamic refresh), Messages button; /tgf settings opens it"
    why_human: "Needs the live Settings UI"
  - test: "Toggle each item level spot, Dynamic refresh, Swipe animations and Region flags with the page open, no /reload"
    expected: "Player tooltip, item tooltip, character sheet row, Inspect row, stock refresh, instant swipe, region flags each switch live"
    why_human: "Live rendering behaviour"
  - test: "Click Whisper presets, close Settings"
    expected: "Finder opens on the Messages tab after Settings closes (not during combat)"
    why_human: "Needs the live client (SettingsPanel strata, tab switching)"
  - test: "Change options, /reload, then relog"
    expected: "Choices persist; fresh install shows all on"
    why_human: "SavedVariables round trip"
---

# Phase 10: Settings Window Verification Report

**Phase Goal:** Players manage every optional extra in one native settings page and can jump from it to the Messages tab
**Status:** human_needed (all code checks pass; live-client items deferred to milestone end)
**Re-verification:** No

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Page under AddOns; `/tgf settings` opens it | VERIFIED | `UI/SettingsPanel.lua` registers a vertical layout category via `RegisterVerticalLayoutCategory` and `RegisterAddOnCategory`. `Core.lua:294` calls `SettingsPanel.Init()`. `Core.lua:324` routes `settings`/`config` to `SP.Open` (`Settings.OpenToCategory`). Without the Settings API it falls back to `PrintAll`. |
| 2 | Each item level spot switchable alone, live | VERIFIED | `ItemLevelUI.lua` reads `Settings.Get` at the point of action: `ilvlPlayerTooltip` (l.67), `ilvlInspect` (l.196), `ilvlCharacterSheet` (l.313), `ilvlItemTooltip` (l.443). Inspect and character sheet also use `OnChange` listeners to redraw at once (l.273, l.361). |
| 3 | Dynamic refresh, swipe and region flags each switchable | VERIFIED | `dynamicRefresh` is read in `InPlace.lua:112` (off gives the stock path) and has an OnChange listener (l.360). `swipeAnimations` is read in `Motion.lua:44` and an OnChange cancels a running swipe (l.254). `regionFlags` is read in `Region.lua:87` and an OnChange calls `Table.RefreshAll` (l.230). Swipe is a child of Dynamic refresh in the UI only, and its value is saved separately. Preview.lua:524 also honours `dynamicRefresh`. |
| 4 | Button opens group finder on Messages tab | VERIFIED (code) | `CreateSettingsButtonInitializer` calls `InPlace.OpenMessages`. If Settings is open, it hooks `SettingsPanel` OnHide once and opens the tab on the next frame. In game it never falls back to the preview, and it refuses in combat. The live effect is a human item. |
| 5 | Defaults on; saved across reload | VERIFIED (code) | Every option has `default = true` (`Settings.lua:166-168`). `Set` writes a boolean to `TerribleGroupFinderDB`, held by reference via `Settings.Init(ns.db)` (`Core.lua:287`). `Get` falls back to the default, and non-boolean saved values are cleaned. Reserved keys are protected. The SavedVariables round trip is a human item. |

**Score:** 5/5

### Behavioral Spot-Checks
Smoke harness (`run.js`, default, `--fallback`, `--attach`): each SUMMARY 0 failed.

### Requirements Coverage
PLAN 10-01 declares SET-01..SET-07 and PLAN 10-02 declares SET-01 and SET-07. REQUIREMENTS.md maps SET-01..07 to Phase 10, with no orphans.

| Req | Status | Evidence |
|-----|--------|----------|
| SET-01 | SATISFIED | Truth 1 |
| SET-02 | SATISFIED | Truth 2 |
| SET-03 | SATISFIED | Truth 3 (`dynamicRefresh`) |
| SET-04 | SATISFIED | Truth 3 (`swipeAnimations`) |
| SET-05 | SATISFIED | Truth 3 (`regionFlags`) |
| SET-06 | SATISFIED (code) | Truth 4 |
| SET-07 | SATISFIED (code) | Truth 5 |

REQUIREMENTS.md checkboxes and table still read Pending. The orchestrator should tick them on completion.

### Anti-Patterns
No TBD/FIXME/XXX debt markers found in the files I read (`Settings.lua`, `UI/SettingsPanel.lua`). Taint is clean: only public registration calls plus a one-time `HookScript` on `SettingsPanel`. IN-02 (Defaults button saves defaults) was intentionally skipped, and this is noted as a minor, non-blocking item.

### Gaps Summary
No code gaps. The remaining items are live-client checks (see frontmatter).

_Verified: 2026-11-14_
_Verifier: Claude (gsd-verifier)_
