---
phase: 18-opt-in-defaults-and-settings-sections
verified: 2026-11-24T00:00:00Z
status: passed # in-game checks passed by the author, 2026-11-25 (18-HUMAN-UAT.md)
score: 7/7 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Fresh install: delete TerribleGroupFinderDB from SavedVariables, /reload"
    expected: "No item level on tooltips, character sheet or Inspect window; no damage meter prompt; the finder table, Dynamic refresh, swipes and region flags work"
    why_human: "Needs the live Forever client"
  - test: "Load with a v0.2.2 saved file (including a table holding only schema = 3)"
    expected: "Item level, talents and meter-on-instance behave as before; an option the player had turned off stays off"
    why_human: "Real SavedVariables and game events"
  - test: "Esc > Options > AddOns > TerribleGroupFinder"
    expected: "Sections in order: Group finder (Elite quest button, Dynamic refresh with Swipe animations under it, Region flags), Player inspection (7 options), Damage meter (2 options + Move), Messages (Edit whisper messages)"
    why_human: "Blizzard Settings UI rendering"
  - test: "/tgf set slotEnchants on|off, and the same for eliteQuestButton and slotItemLevel, with the page open"
    expected: "The change prints and the page checkbox follows at once"
    why_human: "Needs the game's Settings panel and chat"
---

# Phase 18: Opt-in Defaults and Settings Sections Verification Report

**Phase Goal:** The addon only changes the group finder until the player opts in to the extras; nothing changes for existing players; the Settings page is ordered by what matters most
**Status:** human_needed (all code-checkable truths verified; only in-game checks remain)
**Re-verification:** No, initial verification

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | OPT-01: only eliteQuestButton, dynamicRefresh, swipeAnimations, regionFlags default on; the other 9 off, all explicit | VERIFIED | Settings.lua 122-215: 13 options, each with `default = true/false`; fill loop removed (line 216-218 is a plain `S.Register(o)`); Register asserts boolean default (line 37) |
| 2 | OPT-02: saved data keeps the six v0.2.2-on options unless saved as booleans | VERIFIED | Core.lua 29-38 frozen V022_ON (six keys exact), 63-72 schema-4 step uses `existing` computed once at line 54; no `ns.Settings` use in Migrate; walks below |
| 3 | New keys follow new defaults for everyone | VERIFIED | Migrate loops only V022_ON; the new keys are not in it, nor in RESERVED (Settings.lua 20-21) |
| 4 | v0.2.1 table runs schema 3 then 4 in one load | VERIFIED | Walk below |
| 5 | OPT-03: page order Group finder, Player inspection, Damage meter, Messages; swipeAnimations child of dynamicRefresh | VERIFIED (code) | OPTIONS order and sections; SettingsPanel adds a header on each section change in List() order; `parent = "dynamicRefresh"` kept; Move button and Messages header follow the last section. Rendering is a human check |
| 6 | OPT-04: the three new keys registered and settable | VERIFIED (code) | Registered with locked labels and tooltips; the page and `/tgf set` read `ns.Settings.List()`/`Set`. Live behaviour is a human check |
| 7 | CLAUDE.md describes schema 4, defaults, order | VERIFIED | grep: "schema 4" present, "Item level and talents" and "default on except" gone, new section order present, MeterReset line updated, key list and "no feature reads them yet" note present |

**Score:** 7/7

## Migrate walk (by hand, no Lua on PATH)

| Fixture | Result |
|---------|--------|
| `{}` | existing=false; schema 0<3: no meter key, schema=3; <4: skip, schema=4. Saved: `schema=4` only. Get: only the four on. OK |
| `{schema=3}` | existing=true; schema-3 branch skipped; schema-4: the six set true; schema=4. meterResetOnGroup absent (off); slotItemLevel/slotEnchants off; eliteQuestButton on. OK |
| `{schema=3, specPoints=false}` | five set true, specPoints stays false. OK |
| `{schema=2, regionFlags=false}` | existing=true; meterResetOnGroup=true, schema=3; then six true, schema=4; regionFlags stays false (not in the list). OK |
| `{schema=4}` | both branches skipped; nothing written; new defaults. OK |

The ADDON_LOADED fill (Core.lua ~315) runs after Migrate and only fills `schema`, already 4. Migrate runs before Settings.Init.

## Requirements Coverage

| Requirement | Plan | Status | Evidence |
|-------------|------|--------|----------|
| OPT-01 | 18-01 | SATISFIED | Truth 1 |
| OPT-02 | 18-01 | SATISFIED | Truths 2-4 |
| OPT-03 | 18-01 | SATISFIED (code) | Truth 5 |
| OPT-04 | 18-01 | SATISFIED (code) | Truth 6 |

All four IDs in the PLAN frontmatter appear in REQUIREMENTS.md; no orphans. (REQUIREMENTS.md checkboxes and traceability still read Pending: for the orchestrator to update.)

## Anti-Patterns / Checks

- `stylua --check .` clean. CHANGELOG.md and README.md unchanged versus main.
- No TBD/FIXME/XXX introduced in the touched files.
- Accepted per the plan: a v0.1 table saved empty looks new; the page's Defaults button saves the new defaults.
- Info: UI/InPlace.lua header comment still says "default on" for dynamicRefresh, which stays correct.
- No Lua interpreter was available, so Migrate was walked by reading, not executed.

## Gaps Summary

None. The new keys are inert until Phases 19 and 20 read them, as designed. Remaining items are in-game checks (see frontmatter).

_Verifier: Claude (gsd-verifier)_
