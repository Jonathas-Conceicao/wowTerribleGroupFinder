---
status: partial
phase: 14-spec-points
source: [14-VERIFICATION.md, 14-01-SUMMARY.md, 14-02-SUMMARY.md, 14-REVIEW-FIX.md]
started: 2026-11-16T12:00:00Z
updated: 2026-11-16T12:00:00Z
---

## Current Test

[awaiting human testing — deferred to the end of the autonomous run]

## Tests

### 1. Inspected talents are read at all (most important)
expected: Hovering a friendly player (party member, then a stranger) shows "Talents a/b/c" under "Item Level N" a moment after the quiet inspect. If other players never get a talents line, `C_Traits.HasValidInspectData()` may never be true on Forever — report it (the `/tgf ilvl` output helps)
result: [pending]

### 2. Figures match the game's talent frame
expected: `/tgf ilvl` in a group: each member's "C_Traits per tree" matches their talent frame (right-click menu "Inspect Talents"); note what the `pointsSpent` line prints, and the probe's "after clear" line (whether clearing the inspect wipes the data)
result: [pending]

### 3. Your own line
expected: Hovering yourself shows your talents; it follows a dual-spec switch; check whether staged but unapplied talent clicks are counted
result: [pending]

### 4. Inspect Talents is never disturbed
expected: Open "Inspect Talents" on a party member, then hover other players for 10 s: the inspected tree stays intact (no clearing, no switching to another player); also right after choosing the menu entry, before the frame opens
result: [pending]

### 5. No line where there is nothing to show
expected: A low-level player with no talent points shows no talents line and isn't re-inspected on every hover (again after 10 minutes at most); enemies / attackable players never show it
result: [pending]

### 6. Tooltip order on a late answer
expected: When the inspect answers while the tooltip shows, it redraws with the item level line then the talents line, no duplicates or flicker, also with another tooltip addon loaded
result: [pending]

### 7. Setting
expected: Settings > AddOns > TerribleGroupFinder: section "Item level and talents" with "Talent points" second, on by default; turning it off removes only the talents line; `/tgf set specpoints off|on` does the same
result: [pending]

### 8. Data source note and screenshots
expected: Author notes the talent figure comes from the game's talent frame data (C_Traits group currency), not `GetSpecializationInfo().pointsSpent` as first planned; author decides whether README tooltip / settings prints need retaking
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps
