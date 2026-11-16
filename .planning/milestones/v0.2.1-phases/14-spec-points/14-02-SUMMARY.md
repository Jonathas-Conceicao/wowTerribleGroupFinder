---
phase: 14-spec-points
plan: 02
subsystem: item-level-ui
tags: [talents, tooltip, settings]
requires: ["14-01"]
provides:
  - "UI.TalentText, two tracked player tooltip lines (item level, talents)"
  - "specPoints option, section 'Item level and talents'"
affects: []
key-files:
  modified:
    - Settings.lua
    - ItemLevelUI.lua
    - CLAUDE.md
requirements-completed: [SPC-01, SPC-02]
completed: 2026-11-16
---

# Phase 14 Plan 02: Talents line and setting Summary

Friendly players' tooltips (yours included) show a gold `Talents 36/12/3` line after the item level line, gated by the new `specPoints` option ("Talent points", default on), in a settings section renamed "Item level and talents".

## What was built

- `Settings.lua`: `specPoints` right after `ilvlPlayerTooltip`, no parent; the four item level entries moved to the section "Item level and talents". The `o.default = true` loop keeps it on.
- `ItemLevelUI.lua`: `UI.TalentText(list)` (game's `TALENTS` label, fallback "Talents"); the single-line state became two tracked lines (`lines.ilvl`, `lines.talents`) with `ResetLines`, `AddLine(tooltip, which, text)`, `UpdateLine(tooltip, which, text)`. `OnTooltipUnit` and `RefreshTooltip` read both settings where they act. The talents line shows alone when the item level line is off or unknown. One `RequestInspect` call site: asked when the item level is wanted and unknown, or talents are wanted and `TalentsKnown` is false (yours never). Refresh order rule: talents always last, item level never added under it. No new hook.
- `CLAUDE.md`: Settings key list, ItemLevelUI line, SettingsPanel section name.

## Verification

- `stylua --check .` clean; acceptance greps pass.
- Smoke harness (session scratchpad, not shipped), all three modes (`""`, `--fallback`, `--attach`): `SUMMARY: 0 failed`. Settings expectations updated to ten options, the new layout order and section. A "talents tooltip 14-02" block checks: own line alone with ilvl off, gold colour, no inspect for you, all zero gives none, `specPoints` off gives none, unknown player inspected once, the answer adds the talents line, both on gives `Item Level 47` then `Talents 5/6/7` with no second inspect, each setting independent of the other, nothing on an enemy, `TalentText` whole numbers. The harness holds several addon instances that observe the same answer, so that block keeps each text once.

## Deviations from Plan

- The existing "setting off, unknown player: no inspect" check now also turns `specPoints` off (with ilvl off and talents on, an unknown player is rightly inspected). Test expectation only.

## Known Stubs

None.

## HUMAN-UAT

For the author's live Forever check (deferred to the end):
1. `/tgf ilvl` in a group: each member's C_Traits per-tree figure equals their talent frame (menu "Inspect Talents"); note what `pointsSpent` prints (if it matches, record it in PROJECT.md decisions; C_Traits stays the source).
2. The probe's "after clear" line: does `ClearInspectPlayer` empty the inspect config?
3. Own config: `GetCombatConfigIDForSpecGroup(GetActiveSpecGroup())` and `GetActiveConfigID()` agree, type CamelotCombat (4); with dual spec, switch and hover yourself: the line follows.
4. Staged clicks: click talent points without applying, hover yourself; note whether the figure counts them.
5. Open "Inspect Talents" on a party member, then hover other players for 10 s: the inspected tree stays (no swap, no blank).
6. A low-level player (no talent points): no line, and `/tgf ilvl` shows a single inspect for them (no repeats).
7. Settings -> AddOns -> TerribleGroupFinder: section "Item level and talents", "Talent points" second and on; off removes the talents line on the next hover with the item level line unaffected, and vice versa; `/tgf set specpoints off|on` works.
8. Hover an enemy / attackable player: no talents line.

## Notes for the author

- Screenshot reminder: the player tooltip gains a line and the settings page a renamed section; a README tooltip / settings print may need retaking.
- Data source: the talent figure comes from the C_Traits group currency read (as Forever's own talent frame does), not `GetSpecializationInfo(...).pointsSpent` (see 14-01 summary); `/tgf ilvl` prints both for comparison.

## Self-Check: PASSED
